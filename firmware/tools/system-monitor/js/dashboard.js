// js/dashboard.js — TRANEX IPS Mesh Operations Central Controller
// Orchestrates Web Serial, Supabase, and High-Performance UI Views without DOM flickering

window.SM = window.SM || {};

SM.dashboard = (function () {
  const $ = (id) => document.getElementById(id);

  // ── Unified Application State ──────────────────────────────────────────
  const state = {
    nodes: new Map(),      // Map<cleanUuid, NodeObject>
    levels: [],            // Levels/Floors from Supabase
    selectedFloor: 'ALL',
    selectedNodeUuid: null,

    // Gateway / Root Information
    root: {
      connected: false,
      portInfo: 'Disconnected',
      fwMajor: 1,
      fwMinor: 0,
      uptimeSec: 0,
      lastSeen: null,
    },

    // Dynamic Target Firmware Detection
    targetFw: {
      major: null,
      minor: null,
      isManual: false,
    },
    uploadedFw: {
      major: null,
      minor: null,
    },
  };

  // Expose nodes for mesh route calculations
  SM.nodes = state.nodes;

  function fmtTime(date = new Date()) {
    return date.toLocaleTimeString('en-GB', { hour12: false });
  }

  function fmtVersion(major, minor) {
    if (major === null || major === undefined) return '—';
    return `v${major}.${minor !== null && minor !== undefined ? minor : '0'}`;
  }

  function normalizeUuid(uuid) {
    if (!uuid) return '';
    return String(uuid).replace(/[^a-fA-F0-9]/g, '').toLowerCase();
  }

  // Determine effective target firmware dynamically
  function getEffectiveTargetVersion() {
    // 1. Manual override from input boxes
    if (state.targetFw.isManual && state.targetFw.major !== null) {
      return { major: state.targetFw.major, minor: state.targetFw.minor, label: 'Manual' };
    }

    // 2. Uploaded binary file in current session
    if (state.uploadedFw && state.uploadedFw.major !== null) {
      return { major: state.uploadedFw.major, minor: state.uploadedFw.minor, label: 'Uploaded OTA' };
    }

    // 3. Dynamic: highest firmware version detected on active mesh nodes
    let maxMajor = null;
    let maxMinor = null;

    for (const n of state.nodes.values()) {
      if (n.fwMajor !== null && n.fwMajor !== undefined) {
        if (maxMajor === null ||
            n.fwMajor > maxMajor ||
            (n.fwMajor === maxMajor && (n.fwMinor || 0) > (maxMinor || 0))) {
          maxMajor = n.fwMajor;
          maxMinor = n.fwMinor !== null ? n.fwMinor : 0;
        }
      }
    }

    if (maxMajor !== null) {
      return { major: maxMajor, minor: maxMinor, label: 'Auto (Highest)' };
    }

    // 4. Fallback to Root gateway version if connected
    if (state.root.connected && state.root.fwMajor !== null) {
      return { major: state.root.fwMajor, minor: state.root.fwMinor, label: 'Root Gateway' };
    }

    return { major: null, minor: null, label: 'Detecting...' };
  }

  function isFwUpToDate(major, minor) {
    const target = getEffectiveTargetVersion();
    if (target.major === null) return true;
    if (major === null || major === undefined) return false;
    if (major < target.major) return false;
    if (major === target.major && (minor || 0) < (target.minor || 0)) return false;
    return true;
  }

  // ── 1. Load Infrastructure from Supabase ─────────────────────────────────
  async function loadInfrastructure() {
    SM.ui.drawerView.appendLog('Fetching building infrastructure & nodes from Supabase...', 'info');
    try {
      const result = await SM.nodesRepo.refresh();
      state.levels = result.levels || [];

      for (const node of result.nodes || []) {
        const isVirtual = !Boolean(node.esp32_uuid);
        const cleanUuid = node.esp32_uuid ? normalizeUuid(node.esp32_uuid) : `node_${node.node_id}`;
        const displayUuid = node.esp32_uuid ? String(node.esp32_uuid).trim() : `Virtual (ID: ${node.node_id})`;
        const existing = state.nodes.get(cleanUuid);

        state.nodes.set(cleanUuid, {
          nodeId: node.node_id,
          uuid: cleanUuid,
          cleanUuid: cleanUuid,
          displayUuid: displayUuid,
          hasRealUuid: Boolean(node.esp32_uuid),
          isVirtual: isVirtual,
          nameEn: node.name_en || `Node ${node.node_id}`,
          nameAr: node.name_ar || `Node ${node.node_id}`,
          levelId: node.level_id || 'L1',
          type: node.type || 'poi',
          facilityType: node.facility_type,
          x: typeof node.x === 'number' ? node.x : null,
          y: typeof node.y === 'number' ? node.y : null,
          status: isVirtual ? 'virtual' : (existing?.status || 'unknown'),
          hopCount: existing?.hopCount || null,
          parent: existing?.parent || null,
          fwMajor: existing?.fwMajor || null,
          fwMinor: existing?.fwMinor || null,
          lastSeenTime: existing?.lastSeenTime || null,
          timeoutMs: existing?.timeoutMs || SM.config.HEALTH_BASE_TIMEOUT_MS,
          isFromDb: true,
        });
      }

      SM.ui.alertsView.addAlert('info', 'Infrastructure Synchronized', `Discovered ${state.nodes.size} nodes from database.`);
      renderFloorFilterButtons();
      renderInitialViews();
    } catch (err) {
      SM.ui.drawerView.appendLog(`Database sync warning: ${err.message}`, 'warn');
    }
  }

  function renderInitialViews() {
    const target = getEffectiveTargetVersion();
    SM.ui.kpiView.update(state.nodes, target);

    // Initial populate of map & table
    let unmappedIdx = 0;
    for (const node of state.nodes.values()) {
      SM.ui.mapView.patchNode(node, unmappedIdx);
      SM.ui.tableView.patchRow(node, target, state.levels);
      if (node.x === null || node.y === null) unmappedIdx++;
    }
  }

  function renderFloorFilterButtons() {
    const container = $('floorFilterPills');
    if (!container) return;

    let html = `
      <button class="floor-nav-item ${state.selectedFloor === 'ALL' ? 'active' : ''}" data-floor="ALL">
        <div class="floor-name-group">
          <span class="floor-code">ALL</span>
          <span class="floor-label">All Floors</span>
        </div>
        <span class="floor-count">${state.nodes.size}</span>
      </button>
    `;

    for (const lvl of state.levels) {
      const nodesInFloor = Array.from(state.nodes.values()).filter(n => n.levelId === lvl.level_id);
      const count = nodesInFloor.length;
      const onlineCount = nodesInFloor.filter(n => n.status === 'online' || n.status === 'warning').length;
      const countBadgeClass = onlineCount > 0 ? 'floor-count has-online' : 'floor-count';

      html += `
        <button class="floor-nav-item ${state.selectedFloor === lvl.level_id ? 'active' : ''}" data-floor="${lvl.level_id}">
          <div class="floor-name-group">
            <span class="floor-code">${lvl.level_id}</span>
            <span class="floor-label">${lvl.name_en || lvl.name_ar || lvl.level_id}</span>
          </div>
          <span class="${countBadgeClass}">${count}</span>
        </button>
      `;
    }

    container.innerHTML = html;

    container.querySelectorAll('.floor-nav-item').forEach(btn => {
      btn.addEventListener('click', () => {
        state.selectedFloor = btn.getAttribute('data-floor');
        container.querySelectorAll('.floor-nav-item').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        SM.ui.mapView.setFloor(state.selectedFloor);
        const target = getEffectiveTargetVersion();
        SM.ui.tableView.setFloorFilter(state.selectedFloor, state.nodes, target, state.levels);

        // Re-patch visible nodes for the floor
        for (const n of state.nodes.values()) {
          SM.ui.mapView.patchNode(n);
        }
      });
    });
  }

  // ── 2. Live Health Telemetry Packet Handling ─────────────────────────────
  function onHealthData(nodeIdHex, hopCount, status, fwMajor, fwMinor) {
    if (!nodeIdHex) return;

    const now = Date.now();
    const hop = (typeof hopCount === 'number' && !isNaN(hopCount)) ? hopCount : 1;
    const timeoutMs = SM.config.HEALTH_BASE_TIMEOUT_MS + (hop * SM.config.HEALTH_PER_HOP_MARGIN_MS);
    const key = normalizeUuid(nodeIdHex);

    if (!key) return;

    // 1. Find node by exact key
    let node = state.nodes.get(key);

    // 2. If not found, check partial match against registered DB nodes
    if (!node) {
      for (const existing of state.nodes.values()) {
        if (existing.uuid === key || (existing.cleanUuid && existing.cleanUuid === key)) {
          node = existing;
          break;
        }
        // Substring / match without hyphens
        if (existing.cleanUuid && (existing.cleanUuid.includes(key) || key.includes(existing.cleanUuid))) {
          node = existing;
          state.nodes.set(key, node); // Alias
          break;
        }
      }
    }

    // 3. Fallback: check nodesRepo cache
    if (!node && SM.nodesRepo) {
      const dbNode = SM.nodesRepo.lookupByUuid(key);
      if (dbNode) {
        const cleanKey = dbNode.esp32_uuid ? normalizeUuid(dbNode.esp32_uuid) : key;
        node = state.nodes.get(cleanKey);
      }
    }

    let isNew = false;
    let wasOffline = false;

    // 4. If truly a newly discovered dynamic node on the mesh
    if (!node) {
      isNew = true;
      const shortId = key.length >= 4 ? key.slice(-4) : key;
      node = {
        nodeId: null,
        uuid: key,
        cleanUuid: key,
        displayUuid: key.length > 12 ? `${key.slice(0, 8)}...${key.slice(-4)}` : key,
        hasRealUuid: true,
        nameEn: `Mesh Node (${shortId})`,
        nameAr: `عقدة ميش (${shortId})`,
        levelId: 'L1',
        type: 'dynamic',
        facilityType: null,
        x: null,
        y: null,
        isFromDb: false,
      };
      state.nodes.set(key, node);
      SM.ui.alertsView.addAlert('info', 'New Node Joined Mesh', `Node ${shortId} joined mesh topology at Hop ${hop}`, key);
    } else {
      wasOffline = node.status === 'offline' || node.status === 'unknown';
    }

    const isExplicitOffline = status === 'offline';
    const highHopThreshold = (SM.config && SM.config.HIGH_HOP_THRESHOLD) || 9;
    node.status = isExplicitOffline ? 'offline' : (hop >= highHopThreshold ? 'warning' : 'online');
    node.hopCount = hop;
    node.parent = hop === 1 ? 'Root Gateway' : `Hop ${hop - 1} Gateway`;
    node.fwMajor = (fwMajor !== null && fwMajor !== undefined) ? fwMajor : node.fwMajor;
    node.fwMinor = (fwMinor !== null && fwMinor !== undefined) ? fwMinor : node.fwMinor;
    node.lastSeenTime = isExplicitOffline ? now - timeoutMs - 1000 : now;
    node.timeoutMs = timeoutMs;

    if (wasOffline && !isExplicitOffline) {
      SM.ui.alertsView.addAlert('success', 'Node Online', `${node.nameEn} heartbeat received (Hop ${hop})`, key);
    }

    const effectiveTarget = getEffectiveTargetVersion();
    if (node.fwMajor !== null && effectiveTarget.major !== null) {
      if (!isFwUpToDate(node.fwMajor, node.fwMinor) && !node._outdatedAlertSent) {
        node._outdatedAlertSent = true;
        SM.ui.alertsView.addAlert('warning', 'Firmware Outdated', `${node.nameEn} runs ${fmtVersion(node.fwMajor, node.fwMinor)}, target is ${fmtVersion(effectiveTarget.major, effectiveTarget.minor)}`, key);
      }
    }

    // Fine-Grained Reactive Updates: Only the changed node and metrics!
    SM.ui.kpiView.update(state.nodes, effectiveTarget);
    SM.ui.mapView.patchNode(node);
    SM.ui.tableView.patchRow(node, effectiveTarget, state.levels);

    // Persist to local database
    if (SM.localDb) {
      SM.localDb.logTelemetry(node);
    }

    // CRITICAL: Only update the drawer's content passively if it is ALREADY open for this node.
    // NEVER re-open the drawer automatically on heartbeats!
    if (state.selectedNodeUuid === node.uuid && SM.ui.drawerView.isOpen()) {
      SM.ui.drawerView.updateNode(node, state.levels);
    }
  }

  // ── 3. Root Gateway Info ─────────────────────────────────────────────────
  function onRootInfo(info) {
    const wasConnected = state.root.connected;
    state.root.connected = true;
    state.root.fwMajor = info.fw_major;
    state.root.fwMinor = info.fw_minor;
    state.root.uptimeSec = info.uptime_s || 0;
    state.root.lastSeen = Date.now();

    const rootFwEl = $('headerRootFw');
    if (rootFwEl) rootFwEl.textContent = fmtVersion(info.fw_major, info.fw_minor);

    renderHeader();
    if (!wasConnected) {
      SM.ui.alertsView.addAlert('info', 'Root Gateway Connected', `ESP32 Root identified running ${fmtVersion(info.fw_major, info.fw_minor)}`);
    }
    const target = getEffectiveTargetVersion();
    SM.ui.kpiView.update(state.nodes, target);
  }

  // ── 4. Periodic 1-Second Precision Tick ───────────────────────────────────
  function periodicCheck() {
    const now = Date.now();
    const effectiveTarget = getEffectiveTargetVersion();
    let statsChanged = false;

    for (const [uuid, node] of state.nodes.entries()) {
      if (node.status === 'online' || node.status === 'warning') {
        const elapsed = now - (node.lastSeenTime || 0);
        if (elapsed > node.timeoutMs) {
          node.status = 'offline';
          statsChanged = true;
          SM.ui.alertsView.addAlert('critical', 'Node Offline', `Heartbeat timeout for ${node.nameEn} (${(node.timeoutMs / 1000).toFixed(1)}s)`, uuid);
          SM.ui.mapView.patchNode(node);
          SM.ui.tableView.patchRow(node, effectiveTarget, state.levels);
        }
      }
    }

    // Update live clock
    const clockEl = $('liveClock');
    if (clockEl) clockEl.textContent = fmtTime();

    if (statsChanged) {
      SM.ui.kpiView.update(state.nodes, effectiveTarget);
    }

    // Fast-path: update elapsed seconds counters for visible rows
    SM.ui.tableView.updateElapsedTimes(state.nodes);
  }

  // ── 5. Header Status Updates ─────────────────────────────────────────────
  function renderHeader() {
    const rootBadge = $('headerRootBadge');
    const portEl = $('headerPortName');
    const rootFwEl = $('headerRootFw');
    const connectBtn = $('connectBtn');
    const disconnectBtn = $('disconnectBtn');

    const isConn = state.root.connected;

    if (rootBadge) {
      rootBadge.className = `status-pill ${isConn ? 'connected' : 'disconnected'}`;
      rootBadge.innerHTML = `<span class="indicator-dot"></span> ${isConn ? 'Root Connected' : 'Root Disconnected'}`;
    }

    if (portEl) {
      portEl.textContent = isConn ? SM.serial.getPortInfo() : 'Disconnected';
    }

    if (rootFwEl) {
      rootFwEl.textContent = fmtVersion(state.root.fwMajor, state.root.fwMinor);
    }

    if (connectBtn) connectBtn.style.display = isConn ? 'none' : 'inline-flex';
    if (disconnectBtn) disconnectBtn.style.display = isConn ? 'inline-flex' : 'none';
  }

  // ── Selection & Deselection ──────────────────────────────────────────────
  function selectNode(uuid) {
    if (!uuid) {
      deselectNode();
      return;
    }

    state.selectedNodeUuid = uuid;
    const node = state.nodes.get(uuid);
    if (!node) return;

    SM.ui.mapView.selectNode(uuid);
    SM.ui.tableView.selectRow(uuid);
    SM.ui.drawerView.openNode(node, state.levels);
  }

  function deselectNode() {
    state.selectedNodeUuid = null;
    SM.ui.mapView.selectNode(null);
    SM.ui.tableView.selectRow(null);
    SM.ui.drawerView.closeNode();
  }

  // ── 6. Setup DOM Event Listeners ─────────────────────────────────────────
  function setupEventListeners() {
    // Serial Connection
    const connectBtn = $('connectBtn');
    const disconnectBtn = $('disconnectBtn');

    if (connectBtn) {
      connectBtn.addEventListener('click', async () => {
        try {
          await SM.serial.connect();
        } catch (err) {
          SM.ui.drawerView.appendLog(`Serial connect error: ${err.message}`, 'error');
          SM.ui.alertsView.addAlert('critical', 'Connection Failed', err.message);
        }
      });
    }

    if (disconnectBtn) {
      disconnectBtn.addEventListener('click', async () => {
        await SM.serial.disconnect();
      });
    }

    // Table Search
    const searchInput = $('tableSearchInput');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        const q = e.target.value.trim();
        const target = getEffectiveTargetVersion();
        SM.ui.tableView.setSearch(q, state.nodes, target, state.levels);
      });
    }

    // Table Status Filters
    document.querySelectorAll('.table-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.table-filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const f = btn.getAttribute('data-filter');
        const target = getEffectiveTargetVersion();
        SM.ui.tableView.setFilter(f, state.nodes, target, state.levels);
      });
    });

    // Alert Severity Filters
    document.querySelectorAll('.alert-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.alert-filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        SM.ui.alertsView.setFilter(btn.getAttribute('data-filter'));
      });
    });

    // Map Zoom Controls
    const zoomInBtn = $('mapZoomIn');
    const zoomOutBtn = $('mapZoomOut');
    const zoomResetBtn = $('mapZoomReset');

    if (zoomInBtn) zoomInBtn.addEventListener('click', SM.ui.mapView.zoomIn);
    if (zoomOutBtn) zoomOutBtn.addEventListener('click', SM.ui.mapView.zoomOut);
    if (zoomResetBtn) zoomResetBtn.addEventListener('click', SM.ui.mapView.resetZoom);

    // Export Log
    const exportLogBtn = $('exportLogBtn');
    if (exportLogBtn) {
      exportLogBtn.addEventListener('click', () => {
        const consoleEl = $('logConsole');
        const text = consoleEl ? consoleEl.innerText : '';
        const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `tranex_mesh_log_${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '_')}.txt`;
        a.click();
        URL.revokeObjectURL(url);
        SM.ui.drawerView.appendLog('Exported logs file', 'info');
      });
    }

    // Admin Auth
    setupAuthModal();

    // OTA Panel
    setupOtaPanel();

    // Local History Modal
    setupHistoryModal();
  }

  function setupAuthModal() {
    const loginBtn = $('loginBtn');
    const logoutBtn = $('logoutBtn');
    const userEmailEl = $('userEmail');
    const loginModal = $('loginModal');
    const loginForm = $('loginForm');
    const loginError = $('loginError');

    SM.auth.onChange(({ user }) => {
      if (userEmailEl) userEmailEl.textContent = user ? user.email : '';
      if (loginBtn) loginBtn.style.display = user ? 'none' : 'inline-flex';
      if (logoutBtn) logoutBtn.style.display = user ? 'inline-flex' : 'none';
    });

    if (loginBtn && loginModal) {
      loginBtn.addEventListener('click', () => loginModal.classList.add('open'));
    }

    if (logoutBtn) {
      logoutBtn.addEventListener('click', async () => {
        await SM.auth.signOut();
        SM.ui.drawerView.appendLog('Admin signed out', 'warn');
      });
    }

    if (loginForm) {
      loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        if (loginError) loginError.style.display = 'none';
        const email = loginForm.querySelector('#loginEmail').value.trim();
        const pass = loginForm.querySelector('#loginPass').value;
        try {
          await SM.auth.signIn(email, pass);
          if (loginModal) loginModal.classList.remove('open');
          SM.ui.drawerView.appendLog(`Admin authenticated: ${email}`, 'info');
          SM.ui.alertsView.addAlert('success', 'Admin Sign In', `Authenticated as ${email}`);
        } catch (err) {
          if (loginError) {
            loginError.textContent = err.message;
            loginError.style.display = 'block';
          }
        }
      });
    }

    if (loginModal) {
      loginModal.addEventListener('click', (e) => {
        if (e.target === loginModal) loginModal.classList.remove('open');
      });
    }

    SM.auth.init();
  }

  // ── 7. OTA Panel Distribution ────────────────────────────────────────────
  function setupOtaPanel() {
    const dropZone = $('otaDropZone');
    const fileInput = $('otaFileInput');
    const fileNameEl = $('otaFileName');
    const uploadBtn = $('otaUploadBtn');
    const redistributeBtn = $('otaRedistributeBtn');
    const progressWrap = $('otaProgressWrap');
    const progressBar = $('otaProgressBar');
    const progressText = $('otaProgressText');
    const otaStatus = $('otaStatus');
    const targetMajorInput = $('targetFwMajor');
    const targetMinorInput = $('targetFwMinor');

    let selectedFile = null;

    function setStatus(msg) {
      if (otaStatus) otaStatus.textContent = msg;
    }

    function readTarget() {
      const majVal = targetMajorInput?.value?.trim();
      const minVal = targetMinorInput?.value?.trim();
      if (majVal !== "" && majVal !== undefined && !isNaN(parseInt(majVal, 10))) {
        state.targetFw.major = parseInt(majVal, 10);
        state.targetFw.minor = (minVal !== "" && !isNaN(parseInt(minVal, 10))) ? parseInt(minVal, 10) : 0;
        state.targetFw.isManual = true;
      } else {
        state.targetFw.major = null;
        state.targetFw.minor = null;
        state.targetFw.isManual = false;
      }

      const target = getEffectiveTargetVersion();
      SM.ui.kpiView.update(state.nodes, target);
      SM.ui.tableView.refreshVisibility(state.nodes, target, state.levels);
    }

    if (targetMajorInput) targetMajorInput.addEventListener('input', readTarget);
    if (targetMinorInput) targetMinorInput.addEventListener('input', readTarget);

    async function handleFile(file) {
      if (!file) return;
      selectedFile = file;
      let detectedVer = null;

      try {
        const slice = await file.slice(0, 128).arrayBuffer();
        const u8 = new Uint8Array(slice);
        // ESP app descriptor magic: 0xABCD5432 at offset 0x20
        if (u8.length >= 80 && u8[32] === 0x32 && u8[33] === 0x54 && u8[34] === 0xcd && u8[35] === 0xab) {
          let str = '';
          for (let i = 48; i < 80; i++) {
            if (u8[i] === 0) break;
            str += String.fromCharCode(u8[i]);
          }
          if (str) detectedVer = str.trim();
        }
      } catch (e) {}

      const verText = detectedVer ? ` | Version: ${detectedVer}` : '';
      if (fileNameEl) fileNameEl.textContent = `📄 ${file.name} (${(file.size / 1024).toFixed(1)} KB)${verText}`;
      if (uploadBtn) uploadBtn.disabled = false;
      setStatus(`Binary ready: ${file.name}${verText}`);

      if (detectedVer) {
        const match = detectedVer.match(/(\d+)\.(\d+)/);
        if (match && targetMajorInput && targetMinorInput && !state.targetFw.isManual) {
          const parsedMaj = parseInt(match[1], 10);
          const parsedMin = parseInt(match[2], 10);
          targetMajorInput.value = parsedMaj;
          targetMinorInput.value = parsedMin;
          state.uploadedFw.major = parsedMaj;
          state.uploadedFw.minor = parsedMin;
          const target = getEffectiveTargetVersion();
          SM.ui.kpiView.update(state.nodes, target);
          SM.ui.tableView.refreshVisibility(state.nodes, target, state.levels);
        }
      }
    }

    if (dropZone && fileInput) {
      dropZone.addEventListener('click', () => fileInput.click());
      fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) handleFile(e.target.files[0]);
      });

      dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
      });

      dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));

      dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
        if (e.dataTransfer.files.length > 0) handleFile(e.dataTransfer.files[0]);
      });
    }

    if (uploadBtn) {
      uploadBtn.addEventListener('click', async () => {
        if (!selectedFile) return;
        if (!state.root.connected) {
          alert('Please connect to Root Gateway via Serial first.');
          return;
        }

        uploadBtn.disabled = true;
        if (progressWrap) progressWrap.style.display = 'flex';
        setStatus('Broadcasting firmware binary...');

        try {
          await SM.ota.sendFirmware(selectedFile, (pct) => {
            if (progressBar) progressBar.style.width = `${pct}%`;
            if (progressText) progressText.textContent = `${pct}%`;
          });
          setStatus('✅ Firmware broadcast successful!');
          SM.ui.alertsView.addAlert('success', 'OTA Broadcast Completed', `New firmware published to mesh network.`);
        } catch (err) {
          setStatus(`❌ Error: ${err.message}`);
          SM.ui.alertsView.addAlert('critical', 'OTA Failed', err.message);
        } finally {
          uploadBtn.disabled = false;
        }
      });
    }

    if (redistributeBtn) {
      redistributeBtn.addEventListener('click', async () => {
        if (!state.root.connected) {
          alert('Please connect to Root Gateway via Serial first.');
          return;
        }

        redistributeBtn.disabled = true;
        setStatus('Triggering flash redistribution...');

        try {
          await SM.ota.redistributeFirmware();
          setStatus('✅ Flash redistribution initiated.');
          SM.ui.alertsView.addAlert('info', 'Mesh Redistribution', 'Flash redistribution command sent to Root gateway.');
        } catch (err) {
          setStatus(`❌ Error: ${err.message}`);
        } finally {
          redistributeBtn.disabled = false;
        }
      });
    }
  }

  // ── 8. Local Telemetry & Events History Modal ────────────────────────────
  function setupHistoryModal() {
    const openBtn = $('openHistoryBtn');
    const closeBtn = $('closeHistoryModalBtn');
    const modal = $('historyModal');
    const refreshBtn = $('refreshHistoryBtn');
    const exportCsvBtn = $('exportCsvBtn');
    const nodeFilter = $('historyNodeFilter');
    const limitFilter = $('historyLimitFilter');
    const tbody = $('historyTableBody');

    if (!modal) return;

    function populateNodeFilter() {
      if (!nodeFilter) return;
      const currentVal = nodeFilter.value || 'ALL';
      let html = '<option value="ALL">All Nodes</option>';
      for (const node of state.nodes.values()) {
        html += `<option value="${node.uuid}">${node.nameEn} (${node.displayUuid})</option>`;
      }
      nodeFilter.innerHTML = html;
      nodeFilter.value = currentVal;
    }

    async function loadHistoryTable() {
      if (!tbody) return;
      tbody.innerHTML = '<tr><td colspan="7" class="empty-state">Loading telemetry records from local database...</td></tr>';

      const nodeUuid = nodeFilter ? nodeFilter.value : 'ALL';
      const limit = limitFilter ? parseInt(limitFilter.value, 10) || 100 : 100;

      try {
        let records = [];
        if (SM.localDb) {
          records = await SM.localDb.queryHistory({ nodeUuid, limit });
        }

        if (!records || records.length === 0) {
          tbody.innerHTML = '<tr><td colspan="7" class="empty-state">No telemetry records found for selected filter.</td></tr>';
          return;
        }

        let html = '';
        for (const rec of records) {
          const dt = new Date(rec.timestamp);
          const timeStr = dt.toLocaleTimeString('en-GB', { hour12: false }) + '.' + String(dt.getMilliseconds()).padStart(3, '0');
          const dateStr = dt.toLocaleDateString('en-GB');
          const fwStr = (rec.fwMajor !== null && rec.fwMajor !== undefined) ? `v${rec.fwMajor}.${rec.fwMinor || 0}` : '—';
          const statusBadge = rec.status === 'online'
            ? '<span class="status-chip success">ONLINE</span>'
            : (rec.status === 'warning' ? '<span class="status-chip warning">WARNING</span>' : '<span class="status-chip danger">OFFLINE</span>');

          html += `
            <tr>
              <td class="mono" style="font-size: 0.8rem;">
                <div>${timeStr}</div>
                <div class="text-muted" style="font-size: 0.7rem;">${dateStr}</div>
              </td>
              <td>
                <div class="node-name-cell">${rec.nodeName || rec.nodeUuid}</div>
                <div class="mono text-muted" style="font-size: 0.72rem;">${rec.nodeUuid}</div>
              </td>
              <td style="text-align: center;"><span class="floor-badge">${rec.floor || '—'}</span></td>
              <td style="text-align: center;"><span class="mono">Hop ${rec.hop !== null && rec.hop !== undefined ? rec.hop : '—'}</span></td>
              <td style="text-align: center;"><span class="mono text-muted" style="font-size: 0.8rem;">${rec.parent || '—'}</span></td>
              <td style="text-align: center;"><span class="mono">${fwStr}</span></td>
              <td style="text-align: center;">${statusBadge}</td>
            </tr>
          `;
        }
        tbody.innerHTML = html;
      } catch (err) {
        tbody.innerHTML = `<tr><td colspan="7" class="empty-state text-danger">Error querying local database: ${err.message}</td></tr>`;
      }
    }

    if (openBtn) {
      openBtn.addEventListener('click', () => {
        populateNodeFilter();
        modal.classList.add('open');
        loadHistoryTable();
      });
    }

    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        modal.classList.remove('open');
      });
    }

    modal.addEventListener('click', (e) => {
      if (e.target === modal) modal.classList.remove('open');
    });

    if (refreshBtn) {
      refreshBtn.addEventListener('click', loadHistoryTable);
    }

    if (nodeFilter) {
      nodeFilter.addEventListener('change', loadHistoryTable);
    }

    if (limitFilter) {
      limitFilter.addEventListener('change', loadHistoryTable);
    }

    if (exportCsvBtn) {
      exportCsvBtn.addEventListener('click', async () => {
        if (SM.localDb) {
          const nodeUuid = nodeFilter ? nodeFilter.value : 'ALL';
          const records = await SM.localDb.queryHistory({ nodeUuid, limit: 1000 });
          SM.localDb.exportHistoryCsv(records);
        }
      });
    }
  }

  // ── 9. Initialize Module ─────────────────────────────────────────────────
  function init() {
    if (SM.localDb) {
      SM.localDb.init();
    }
    SM.ui.kpiView; // Verified loaded
    SM.ui.alertsView.init();
    SM.ui.drawerView.init({ onClose: deselectNode });
    SM.ui.mapView.init({ onNodeSelect: selectNode });
    SM.ui.tableView.init({ onNodeSelect: selectNode });

    // Serial callbacks
    SM.serial.onConnectionChange((connected) => {
      state.root.connected = connected;
      renderHeader();
      SM.ui.drawerView.appendLog(connected ? 'Serial connection established' : 'Serial disconnected', connected ? 'info' : 'warn');
    });

    SM.serial.onRootInfo(onRootInfo);

    // Fixed callback: handles both positional arguments and object argument safely
    SM.serial.onHealthLine((nodeIdHex, hopCount, status, fwMajor, fwMinor, updateObj) => {
      let id = nodeIdHex;
      let hop = hopCount;
      let st = status;
      let maj = fwMajor;
      let min = fwMinor;

      if (typeof nodeIdHex === 'object' && nodeIdHex !== null) {
        id = nodeIdHex.nodeIdHex || nodeIdHex.node_id || nodeIdHex.nodeId;
        hop = nodeIdHex.hopCount || nodeIdHex.hop_count;
        st = nodeIdHex.status;
        maj = nodeIdHex.fwMajor || nodeIdHex.fw_major;
        min = nodeIdHex.fwMinor || nodeIdHex.fw_minor;
      }

      onHealthData(id, hop, st, maj, min);
    });

    SM.serial.onRawLine((line) => {
      SM.ui.drawerView.appendLog(line, 'info');
    });

    setupEventListeners();
    loadInfrastructure();

    // Start precision 1-second interval
    setInterval(periodicCheck, 1000);
  }

  return {
    init,
    selectNode,
    deselectNode,
  };
})();

// Bootstrap on DOM Ready
document.addEventListener('DOMContentLoaded', () => {
  SM.dashboard.init();
});
