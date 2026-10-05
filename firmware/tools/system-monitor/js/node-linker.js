// js/node-linker.js — TRANEX Interactive Graph & Path Linker Engine
// Complete GUI for connecting nodes, splitting paths, and syncing with Supabase

window.NL = (function () {
  const $ = (id) => document.getElementById(id);

  // Canvas Geometry & Scaling
  const BASE_SCALE = 14; // 1m = 14px
  const PAD = 80;
  const GRID_SIZE = 180; // 0 to 180m coordinate grid

  let state = {
    activeFloor: 'L4', // Default floor with rich test nodes
    activeMode: 'select', // 'select' | 'connect' | 'split' | 'delete'
    selectedNodeId: null,
    selectedEdgeId: null,
    connectStartNodeId: null,
    splitCandidateNodeId: null,
    splitCandidateEdgeId: null,
    hoveredNodeId: null,
    hoveredEdgeId: null,
    mouseCoord: { x: 0, y: 0 },
    floorSpan: 1800,
    panZoom: {
      centerX: 1200,
      centerY: 1200,
      zoom: 1,
      panX: 0,
      panY: 0,
      isPanning: false,
      startX: 0,
      startY: 0,
      startPanX: 0,
      startPanY: 0,
    },
    viewOptions: {
      showLabels: true,
      showLengths: true,
      showGrid: true,
      filterIsolated: false,
    },
    searchQuery: '',
    undoStack: [],
    redoStack: [],
  };

  let svgRoot = null;
  let gridLayer = null;
  let edgesLayer = null;
  let previewLayer = null;
  let nodesLayer = null;
  let isInitialized = false;
  let isInitializing = false;

  // ── Initialization ──────────────────────────────────────────────────────────
  async function init() {
    if (isInitialized || isInitializing) return;
    isInitializing = true;

    svgRoot = $('canvasSvg');
    if (!svgRoot) {
      console.error('[node-linker] canvasSvg element not found');
      isInitializing = false;
      return;
    }

    svgRoot.setAttribute('viewBox', '200 200 1800 1800');
    setupSvgLayers();
    setupPanZoom();
    setupEventListeners();
    setupKeyboardShortcuts();

    showToast('جاري الاتصال بـ Supabase وتحميل شبكة النودز والمسارات...', 'info');

    try {
      if (window.SM && SM.nodesRepo) {
        await SM.nodesRepo.refresh();
      }

      let allNodes = SM.nodesRepo.getAllNodes();
      let allLevels = SM.nodesRepo.getLevels();
      let allEdges = SM.nodesRepo.getEdges();

      if (allNodes.length === 0) {
        console.warn('[node-linker] No nodes loaded, attempting local fallback...');
        await SM.nodesRepo.loadLocalFallback();
        allNodes = SM.nodesRepo.getAllNodes();
        allLevels = SM.nodesRepo.getLevels();
        allEdges = SM.nodesRepo.getEdges();
      }

      console.log(`[node-linker] Loaded ${allNodes.length} nodes, ${allEdges.length} edges`);

      // Determine initial floor
      const floorsWithNodes = allLevels.filter(lvl => 
        allNodes.some(n => n.level_id === lvl.level_id)
      );
      if (floorsWithNodes.length > 0) {
        const hasL4 = floorsWithNodes.find(l => l.level_id === 'L4');
        state.activeFloor = hasL4 ? 'L4' : floorsWithNodes[0].level_id;
      }

      isInitialized = true;
      renderFloorTabs();
      renderNodeList();
      renderCanvas();
      fitFloorToView();
      updateInspector();
      updateHelperBanner();
      updatePendingBadge();

      showToast(`✅ تم بنجاح تحميل ${allNodes.length} نقطة و ${allEdges.length} مسار`, 'success');
    } catch (err) {
      console.error('[node-linker] Initialization error:', err);
      showToast('❌ تعذر الاتصال بقاعدة البيانات: ' + (err.message || err), 'error');
    } finally {
      isInitializing = false;
    }
  }

  function setupSvgLayers() {
    svgRoot.innerHTML = `
      <defs>
        <pattern id="grid1m" width="${BASE_SCALE}" height="${BASE_SCALE}" patternUnits="userSpaceOnUse">
          <path d="M ${BASE_SCALE} 0 L 0 0 0 ${BASE_SCALE}" fill="none" stroke="rgba(255,255,255,0.03)" stroke-width="0.5"/>
        </pattern>
        <pattern id="grid10m" width="${BASE_SCALE * 10}" height="${BASE_SCALE * 10}" patternUnits="userSpaceOnUse">
          <rect width="${BASE_SCALE * 10}" height="${BASE_SCALE * 10}" fill="url(#grid1m)"/>
          <path d="M ${BASE_SCALE * 10} 0 L 0 0 0 ${BASE_SCALE * 10}" fill="none" stroke="rgba(243, 111, 33, 0.15)" stroke-width="1"/>
        </pattern>
        <filter id="glow-orange" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="5" result="blur"/>
          <feMerge>
            <feMergeNode in="blur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
        <filter id="glow-cyan" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="6" result="blur"/>
          <feMerge>
            <feMergeNode in="blur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
      </defs>
      <!-- Background grid (non-interactive, clicks pass through) -->
      <g id="gridLayer" style="pointer-events: none;"></g>
      <!-- Dedicated transparent canvas hit target for panning and deselecting -->
      <rect id="canvasBgHit" x="-10000" y="-10000" width="20000" height="20000" fill="transparent" style="cursor: grab;" />
      <!-- Edges Layer -->
      <g id="edgesLayer"></g>
      <!-- Preview Layer (non-interactive, strictly visual feedback) -->
      <g id="previewLayer" style="pointer-events: none;"></g>
      <!-- Nodes Layer (topmost for effortless clicking) -->
      <g id="nodesLayer"></g>
    `;

    gridLayer = $('gridLayer');
    edgesLayer = $('edgesLayer');
    previewLayer = $('previewLayer');
    nodesLayer = $('nodesLayer');
  }

  // ── Floor Tabs & Stats ──────────────────────────────────────────────────────
  function renderFloorTabs() {
    const container = $('floorTabsContainer');
    if (!container) return;

    const levels = SM.nodesRepo.getLevels();
    const allNodes = SM.nodesRepo.getAllNodes();

    let html = `
      <button class="floor-tab ${state.activeFloor === 'ALL' ? 'active' : ''}" data-floor="ALL">
        <span>الكل</span>
        <span class="count">${allNodes.length}</span>
      </button>
    `;

    for (const lvl of levels) {
      const floorNodes = allNodes.filter(n => n.level_id === lvl.level_id);
      const isActive = state.activeFloor === lvl.level_id;
      html += `
        <button class="floor-tab ${isActive ? 'active' : ''}" data-floor="${lvl.level_id}" title="${lvl.name_ar}">
          <span>${lvl.level_id}</span>
          <span class="count">${floorNodes.length}</span>
        </button>
      `;
    }

    container.innerHTML = html;

    container.querySelectorAll('.floor-tab').forEach(btn => {
      btn.addEventListener('click', () => {
        setFloor(btn.dataset.floor);
      });
    });
  }

  function setFloor(floorId) {
    if (state.activeFloor === floorId) return;
    state.activeFloor = floorId;
    clearSelection();
    renderFloorTabs();
    renderNodeList();
    renderCanvas();
    fitFloorToView();
    updateInspector();
  }

  // ── Coordinates & Geometry ──────────────────────────────────────────────────
  function toScreenCoords(node) {
    if (!node || node.x === null || node.y === null || isNaN(node.x) || isNaN(node.y)) {
      return null;
    }
    const nx = Number(node.x);
    const ny = Number(node.y);
    return {
      x: PAD + ny * BASE_SCALE,
      y: PAD + nx * BASE_SCALE,
    };
  }

  function getFloorNodes() {
    const all = SM.nodesRepo.getAllNodes();
    let nodes = state.activeFloor === 'ALL' ? all : all.filter(n => n.level_id === state.activeFloor);
    
    // Filter out unpositioned nodes if any
    nodes = nodes.filter(n => n.x !== null && n.y !== null && !isNaN(n.x) && !isNaN(n.y));

    if (state.searchQuery) {
      const q = state.searchQuery.trim().toLowerCase();
      nodes = nodes.filter(n => 
        String(n.node_id).includes(q) ||
        (n.name_ar && n.name_ar.toLowerCase().includes(q)) ||
        (n.name_en && n.name_en.toLowerCase().includes(q)) ||
        (n.type && n.type.toLowerCase().includes(q))
      );
    }

    if (state.viewOptions.filterIsolated) {
      nodes = nodes.filter(n => {
        const conns = (SM.nodesRepo && typeof SM.nodesRepo.getConnectedEdges === 'function') 
          ? SM.nodesRepo.getConnectedEdges(n.node_id) 
          : [];
        return conns.length === 0;
      });
    }

    return nodes;
  }

  function getFloorEdges() {
    const allEdges = SM.nodesRepo.getEdges();
    if (state.activeFloor === 'ALL') return allEdges;

    return allEdges.filter(e => {
      const na = SM.nodesRepo.lookupById(e.node_id_a);
      const nb = SM.nodesRepo.lookupById(e.node_id_b);
      if (!na || !nb) return false;
      return na.level_id === state.activeFloor || nb.level_id === state.activeFloor;
    });
  }

  // ── Render SVG Canvas ───────────────────────────────────────────────────────
  function renderCanvas() {
    if (!svgRoot) return;
    renderGrid();
    renderEdges();
    renderNodes();
    renderPreview();
    updateViewBox();

    // Check empty warning state
    const allNodes = SM.nodesRepo.getAllNodes();
    const warnEl = $('canvasEmptyWarning');
    if (warnEl) {
      warnEl.style.display = (allNodes.length === 0) ? 'block' : 'none';
    }
  }

  function renderGrid() {
    if (!gridLayer) return;
    if (!state.viewOptions.showGrid) {
      gridLayer.innerHTML = '';
      return;
    }

    const totalW = GRID_SIZE * BASE_SCALE + PAD * 2;
    const totalH = GRID_SIZE * BASE_SCALE + PAD * 2;

    let html = `
      <rect x="-3000" y="-3000" width="${totalW + 6000}" height="${totalH + 6000}" fill="#0A0A0A" />
      <rect x="${PAD}" y="${PAD}" width="${GRID_SIZE * BASE_SCALE}" height="${GRID_SIZE * BASE_SCALE}" fill="url(#grid10m)" />
      <rect x="${PAD}" y="${PAD}" width="${GRID_SIZE * BASE_SCALE}" height="${GRID_SIZE * BASE_SCALE}" 
            fill="none" stroke="rgba(243, 111, 33, 0.4)" stroke-width="1.5" />
    `;

    // Coordinates tick markers every 10m
    for (let m = 0; m <= GRID_SIZE; m += 10) {
      const pos = PAD + m * BASE_SCALE;
      // Top Horizontal axis (Y meters)
      html += `
        <text x="${pos}" y="${PAD - 12}" fill="#FFA040" font-size="11" font-family="monospace" text-anchor="middle" font-weight="bold">${m}m</text>
        <text x="${PAD - 12}" y="${pos + 4}" fill="#FFA040" font-size="11" font-family="monospace" text-anchor="end" font-weight="bold">${m}m</text>
      `;
    }

    // Watermark floor title in canvas background
    const currentLvl = (SM.nodesRepo && typeof SM.nodesRepo.getLevel === 'function') ? SM.nodesRepo.getLevel(state.activeFloor) : null;
    const floorLabel = state.activeFloor === 'ALL' ? 'جميع الأدوار (ALL FLOORS)' : (currentLvl ? `${currentLvl.name_ar} (${state.activeFloor})` : state.activeFloor);
    html += `
      <text x="${PAD + 25}" y="${PAD + 55}" fill="rgba(243, 111, 33, 0.22)" font-size="34" font-family="'Inter', sans-serif" font-weight="900" pointer-events="none">${floorLabel}</text>
    `;

    gridLayer.innerHTML = html;
  }

  function renderEdges() {
    if (!edgesLayer) return;
    edgesLayer.innerHTML = '';

    const edges = getFloorEdges();

    for (const edge of edges) {
      const na = SM.nodesRepo.lookupById(edge.node_id_a);
      const nb = SM.nodesRepo.lookupById(edge.node_id_b);
      if (!na || !nb) continue;

      const pa = toScreenCoords(na);
      const pb = toScreenCoords(nb);
      if (!pa || !pb) continue;

      const isSelected = state.selectedEdgeId === edge.edge_id;
      const isVertical = edge.kind === 'elevator' || edge.kind === 'stairs';
      const isDraft = edge._isDraft || String(edge.edge_id).startsWith('draft_');

      const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
      g.setAttribute('class', `canvas-edge-group ${isSelected ? 'selected' : ''} ${isDraft ? 'draft' : ''}`);
      g.setAttribute('data-edge-id', edge.edge_id);

      // Stroke styles
      let strokeColor = isVertical ? '#A855F7' : (isDraft ? '#00E5FF' : '#FFFFFF');
      let strokeWidth = isDraft ? 4 : 3.5;
      let strokeOpacity = isDraft ? 0.9 : 0.45;
      let dashArray = isVertical ? '6,6' : (isDraft ? '8,4' : 'none');

      if (isSelected) {
        strokeColor = '#F36F21';
        strokeWidth = 5.5;
        strokeOpacity = 1;
        dashArray = '8,4';
      }

      // Invisible thick hit-area (28px) for effortless mouse targeting
      const hitLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      hitLine.setAttribute('x1', pa.x);
      hitLine.setAttribute('y1', pa.y);
      hitLine.setAttribute('x2', pb.x);
      hitLine.setAttribute('y2', pb.y);
      hitLine.setAttribute('stroke', 'transparent');
      hitLine.setAttribute('stroke-width', '28');
      hitLine.style.cursor = 'pointer';

      // Visible styled line
      const visLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      visLine.setAttribute('class', 'vis-line');
      visLine.setAttribute('x1', pa.x);
      visLine.setAttribute('y1', pa.y);
      visLine.setAttribute('x2', pb.x);
      visLine.setAttribute('y2', pb.y);
      visLine.setAttribute('stroke', strokeColor);
      visLine.setAttribute('stroke-width', strokeWidth);
      visLine.setAttribute('stroke-opacity', strokeOpacity);
      visLine.setAttribute('stroke-dasharray', dashArray);
      visLine.setAttribute('stroke-linecap', 'round');
      visLine.style.pointerEvents = 'none';

      g.appendChild(hitLine);
      g.appendChild(visLine);

      // Distance tag badge at midpoint
      if (state.viewOptions.showLengths || isSelected || isDraft) {
        const mx = (pa.x + pb.x) / 2;
        const my = (pa.y + pb.y) / 2;
        const dist = edge.distance_meters !== null ? edge.distance_meters : SM.nodesRepo.calculateDistance(na, nb);

        const badgeG = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        badgeG.setAttribute('transform', `translate(${mx}, ${my})`);
        badgeG.style.pointerEvents = 'none';

        const textLen = isDraft ? `${dist}m ✎` : `${dist}m`;
        const badgeW = textLen.length * 7 + 14;

        let badgeFill = '#1C1C1C';
        let badgeStroke = 'rgba(255,255,255,0.3)';
        let textFill = '#FFFFFF';

        if (isSelected) {
          badgeFill = '#F36F21';
          badgeStroke = '#FFA040';
          textFill = '#000000';
        } else if (isDraft) {
          badgeFill = 'rgba(0, 229, 255, 0.16)';
          badgeStroke = '#00E5FF';
          textFill = '#00E5FF';
        }

        badgeG.innerHTML = `
          <rect x="-${badgeW/2}" y="-10" width="${badgeW}" height="20" rx="5"
                fill="${badgeFill}"
                stroke="${badgeStroke}" stroke-width="1.2" />
          <text y="4" text-anchor="middle" fill="${textFill}"
                font-size="10" font-family="monospace" font-weight="700">${textLen}</text>
        `;
        g.appendChild(badgeG);
      }

      // Edge Event Listeners — Pure class toggle, ZERO DOM DESTRUCTION
      g.addEventListener('mouseenter', () => {
        state.hoveredEdgeId = edge.edge_id;
        g.classList.add('hovered');
        updateHelperBanner();
        if (state.activeMode === 'split' || (state.activeMode === 'select' && state.selectedNodeId)) {
          renderPreview();
        }
      });

      g.addEventListener('mouseleave', () => {
        if (state.hoveredEdgeId === edge.edge_id) {
          state.hoveredEdgeId = null;
          g.classList.remove('hovered');
          updateHelperBanner();
          if (previewLayer && state.activeMode !== 'connect') {
            previewLayer.innerHTML = '';
          }
        }
      });

      g.addEventListener('click', (e) => {
        e.stopPropagation();
        handleEdgeClick(edge);
      });

      edgesLayer.appendChild(g);
    }
  }

  function renderNodes() {
    if (!nodesLayer) return;
    nodesLayer.innerHTML = '';

    const nodes = getFloorNodes();

    for (const node of nodes) {
      const pt = toScreenCoords(node);
      if (!pt) continue;

      const isSelected = state.selectedNodeId === node.node_id;
      const isConnectStart = state.connectStartNodeId === node.node_id;
      const isSplitCandidate = state.splitCandidateNodeId === node.node_id;

      const isVertical = node.type === 'elevator' || node.type === 'stairs' || 
                         (node.name_ar && (node.name_ar.includes('أسانسير') || node.name_ar.includes('سلم')));
      const isPOI = node.facility_type === 'office' || (node.name_ar && node.name_ar.includes('لجنة'));

      // Color scheme
      let baseColor = '#3DDC84'; // Emerald for walk corridors
      if (isVertical) baseColor = '#A855F7'; // Purple for elevator/stairs
      else if (isPOI) baseColor = '#00A8FF'; // Sky blue for offices / committee rooms

      const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
      g.setAttribute('class', `canvas-node-group ${isSelected ? 'selected' : ''}`);
      g.setAttribute('transform', `translate(${pt.x}, ${pt.y})`);
      g.style.cursor = 'pointer';

      let inner = '';

      // Selection Halo
      if (isSelected || isConnectStart || isSplitCandidate) {
        inner += `
          <circle r="22" fill="none" stroke="#F36F21" stroke-width="3" opacity="0.85" filter="url(#glow-orange)">
            <animate attributeName="r" values="18;24;18" dur="2s" repeatCount="indefinite"/>
          </circle>
        `;
      }

      // Outer & Center dots (Larger, more visible!)
      inner += `
        <circle class="node-outer" r="14" fill="#141414" stroke="${(isSelected || isConnectStart) ? '#F36F21' : baseColor}" stroke-width="${isSelected ? 3.5 : 2.5}" />
        <circle class="node-inner" r="6" fill="${(isSelected || isConnectStart) ? '#FFA040' : baseColor}" />
      `;

      // Labels
      if (state.viewOptions.showLabels || isSelected) {
        const labelText = node.name_ar || node.name_en || `Node ${node.node_id}`;
        const idBadge = `#${node.node_id}`;
        
        inner += `
          <g class="node-label-pill" transform="translate(0, -22)" style="pointer-events: none;">
            <rect x="-50" y="-14" width="100" height="18" rx="4"
                  fill="rgba(18, 18, 18, 0.94)" stroke="${isSelected ? '#F36F21' : 'rgba(255,255,255,0.25)'}" stroke-width="1" />
            <text x="0" y="-1" text-anchor="middle" fill="${isSelected ? '#FFA040' : '#FFFFFF'}"
                  font-size="10" font-family="'Inter', sans-serif" font-weight="600">${labelText}</text>
          </g>
          <text y="24" text-anchor="middle" fill="${isSelected ? '#FFA040' : '#A0A0A0'}" font-size="9" font-family="monospace" font-weight="700" style="pointer-events: none;">
            ${idBadge}
          </text>
        `;
      }

      g.innerHTML = inner;

      // Node Event Listeners — Pure class toggle, ZERO DOM DESTRUCTION
      g.addEventListener('mouseenter', () => {
        state.hoveredNodeId = node.node_id;
        g.classList.add('hovered');
        updateHelperBanner();
        if (state.activeMode === 'connect' && state.connectStartNodeId) {
          renderPreview();
        }
      });

      g.addEventListener('mouseleave', () => {
        if (state.hoveredNodeId === node.node_id) {
          state.hoveredNodeId = null;
          g.classList.remove('hovered');
          updateHelperBanner();
        }
      });

      g.addEventListener('click', (e) => {
        e.stopPropagation();
        handleNodeClick(node);
      });

      nodesLayer.appendChild(g);
    }
  }

  function renderPreview() {
    if (!previewLayer) return;
    previewLayer.innerHTML = '';

    // 1. Connect Mode rubberband line from connectStartNode to cursor
    if (state.activeMode === 'connect' && state.connectStartNodeId) {
      const startNode = SM.nodesRepo.lookupById(state.connectStartNodeId);
      if (startNode) {
        const startPt = toScreenCoords(startNode);
        if (startPt) {
          let endX = state.mouseCoord.x;
          let endY = state.mouseCoord.y;
          let targetDist = '';

          if (state.hoveredNodeId && state.hoveredNodeId !== startNode.node_id) {
            const hNode = SM.nodesRepo.lookupById(state.hoveredNodeId);
            const hPt = toScreenCoords(hNode);
            if (hPt) {
              endX = hPt.x;
              endY = hPt.y;
              const d = SM.nodesRepo.calculateDistance(startNode, hNode);
              targetDist = `${d}m`;
            }
          }

          let html = `
            <g style="pointer-events: none;">
              <line x1="${startPt.x}" y1="${startPt.y}" x2="${endX}" y2="${endY}"
                    stroke="#F36F21" stroke-width="3" stroke-dasharray="6,5" opacity="0.95" />
          `;

          if (targetDist) {
            const mx = (startPt.x + endX) / 2;
            const my = (startPt.y + endY) / 2;
            html += `
              <g transform="translate(${mx}, ${my})">
                <rect x="-26" y="-11" width="52" height="22" rx="4" fill="#F36F21" />
                <text y="4" text-anchor="middle" fill="#000000" font-size="10" font-family="monospace" font-weight="700">${targetDist}</text>
              </g>
            `;
          }

          html += `</g>`;
          previewLayer.innerHTML = html;
        }
      }
    }

    // 2. Split Preview: When a node is selected and user hovers over an edge (or vice versa)
    const splitNodeId = state.splitCandidateNodeId || (state.activeMode === 'split' ? state.selectedNodeId : state.selectedNodeId);
    const splitEdgeId = state.hoveredEdgeId || state.selectedEdgeId;

    if (splitNodeId && splitEdgeId && (state.activeMode === 'split' || state.hoveredEdgeId || state.activeMode === 'select')) {
      const nodeC = SM.nodesRepo.lookupById(splitNodeId);
      const edge = SM.nodesRepo.getEdges().find(e => e.edge_id === splitEdgeId);

      if (nodeC && edge && Number(edge.node_id_a) !== Number(nodeC.node_id) && Number(edge.node_id_b) !== Number(nodeC.node_id)) {
        const nodeA = SM.nodesRepo.lookupById(edge.node_id_a);
        const nodeB = SM.nodesRepo.lookupById(edge.node_id_b);

        const pa = toScreenCoords(nodeA);
        const pb = toScreenCoords(nodeB);
        const pc = toScreenCoords(nodeC);

        if (pa && pb && pc) {
          previewLayer.innerHTML = `
            <g style="pointer-events: none;">
              <!-- Red dashed highlight on original edge to be deleted -->
              <line x1="${pa.x}" y1="${pa.y}" x2="${pb.x}" y2="${pb.y}"
                    stroke="#EF4444" stroke-width="5" stroke-dasharray="7,5" opacity="0.95" />
              
              <!-- Green glowing lines from C to A and C to B -->
              <line x1="${pc.x}" y1="${pc.y}" x2="${pa.x}" y2="${pa.y}"
                    stroke="#3DDC84" stroke-width="3.5" stroke-dasharray="5,4" filter="url(#glow-orange)" />
              <line x1="${pc.x}" y1="${pc.y}" x2="${pb.x}" y2="${pb.y}"
                    stroke="#3DDC84" stroke-width="3.5" stroke-dasharray="5,4" filter="url(#glow-orange)" />

              <!-- Middle indicator tag -->
              <g transform="translate(${pc.x}, ${pc.y - 38})">
                <rect x="-70" y="-13" width="140" height="26" rx="5" fill="rgba(20,20,20,0.96)" stroke="#3DDC84" stroke-width="1.5" />
                <text y="4" text-anchor="middle" fill="#3DDC84" font-size="10.5" font-family="'Inter', sans-serif" font-weight="700">✂️ إدراج في المنتصف</text>
              </g>
            </g>
          `;
        }
      }
    }
  }

  // ── Core Interaction Logic ──────────────────────────────────────────────────
  async function handleNodeClick(node) {
    console.log('[node-linker] Clicked node:', node.node_id);

    // 1. In CONNECT Mode
    if (state.activeMode === 'connect') {
      if (!state.connectStartNodeId) {
        state.connectStartNodeId = node.node_id;
        state.selectedNodeId = node.node_id;
        updateInspector();
        renderCanvas();
        updateHelperBanner();
        showToast(`اخترت النقطة الأولى #${node.node_id} (${node.name_ar}) — اضغط على النقطة الثانية الآن للربط`, 'info');
      } else if (state.connectStartNodeId === node.node_id) {
        state.connectStartNodeId = null;
        renderCanvas();
        updateHelperBanner();
      } else {
        const nodeAId = state.connectStartNodeId;
        const nodeBId = node.node_id;
        await executeCreateEdge(nodeAId, nodeBId);
        state.connectStartNodeId = node.node_id;
        state.selectedNodeId = node.node_id;
        renderCanvas();
        updateInspector();
        updateHelperBanner();
      }
      return;
    }

    // 2. In SPLIT Mode
    if (state.activeMode === 'split') {
      state.splitCandidateNodeId = node.node_id;
      state.selectedNodeId = node.node_id;
      
      if (state.splitCandidateEdgeId) {
        await executeSplitEdge(state.splitCandidateEdgeId, node.node_id);
      } else {
        showToast(`اخترت النقطة #${node.node_id} (${node.name_ar}) — اضغط الآن على المسار المراد إدراجها في منتصفه`, 'info');
      }
      renderCanvas();
      updateInspector();
      updateHelperBanner();
      return;
    }

    // 3. In DELETE Mode
    if (state.activeMode === 'delete') {
      state.selectedNodeId = node.node_id;
      renderCanvas();
      updateInspector();
      return;
    }

    // 4. In SELECT Mode (Default)
    if (state.selectedEdgeId) {
      const edge = SM.nodesRepo.getEdges().find(e => e.edge_id === state.selectedEdgeId);
      if (edge && edge.node_id_a !== node.node_id && edge.node_id_b !== node.node_id) {
        await executeSplitEdge(edge.edge_id, node.node_id);
        return;
      }
    }

    state.selectedNodeId = node.node_id;
    state.selectedEdgeId = null;
    state.splitCandidateEdgeId = null;
    renderCanvas();
    renderNodeList();
    updateInspector();
    updateHelperBanner();
  }

  async function handleEdgeClick(edge) {
    console.log('[node-linker] Clicked edge:', edge.edge_id);

    // 1. In DELETE Mode: Immediately delete
    if (state.activeMode === 'delete') {
      await executeDeleteEdge(edge.edge_id);
      return;
    }

    // 2. In SPLIT Mode
    if (state.activeMode === 'split') {
      state.splitCandidateEdgeId = edge.edge_id;
      state.selectedEdgeId = edge.edge_id;

      if (state.splitCandidateNodeId) {
        await executeSplitEdge(edge.edge_id, state.splitCandidateNodeId);
      } else if (state.selectedNodeId) {
        await executeSplitEdge(edge.edge_id, state.selectedNodeId);
      } else {
        showToast(`اخترت المسار #${edge.edge_id} — اضغط الآن على النقطة المراد إدراجها في المنتصف`, 'info');
      }
      renderCanvas();
      updateInspector();
      updateHelperBanner();
      return;
    }

    // 3. In SELECT Mode:
    if (state.selectedNodeId) {
      const node = SM.nodesRepo.lookupById(state.selectedNodeId);
      if (node && edge.node_id_a !== node.node_id && edge.node_id_b !== node.node_id) {
        await executeSplitEdge(edge.edge_id, node.node_id);
        return;
      }
    }

    state.selectedEdgeId = edge.edge_id;
    state.selectedNodeId = null;
    state.splitCandidateEdgeId = edge.edge_id;
    renderCanvas();
    updateInspector();
    updateHelperBanner();
  }

  // ── Database Operations (Create, Split, Delete - Staged Mode) ───────────────
  async function executeCreateEdge(nodeAId, nodeBId, customDist = null, kind = 'walk') {
    const na = SM.nodesRepo.lookupById(nodeAId);
    const nb = SM.nodesRepo.lookupById(nodeBId);
    if (!na || !nb) return;

    try {
      const newEdge = await SM.nodesRepo.addEdge({
        nodeIdA: nodeAId,
        nodeIdB: nodeBId,
        distanceMeters: customDist,
        kind: kind,
      });

      state.undoStack.push({
        type: 'create',
        edge: newEdge,
        nodeA: na,
        nodeB: nb,
      });
      state.redoStack = [];

      const summary = SM.nodesRepo.getStagedSummary();
      showToast(`✏️ تم إدراج مسار بالمسودة بين "${na.name_ar}" و "${nb.name_ar}" (${newEdge.distance_meters}م) [${summary.total} تعديل بالمسودة]`, 'success');
      
      updatePendingBadge();
      renderCanvas();
      renderNodeList();
      updateInspector();
    } catch (err) {
      console.error('[node-linker] Failed to create edge:', err);
      showToast(`❌ تعذر إنشاء المسار: ${err.message || err}`, 'error');
    }
  }

  async function executeDeleteEdge(edgeId) {
    const edge = SM.nodesRepo.getEdges().find(e => String(e.edge_id) === String(edgeId));
    if (!edge) return;

    const na = SM.nodesRepo.lookupById(edge.node_id_a);
    const nb = SM.nodesRepo.lookupById(edge.node_id_b);

    try {
      await SM.nodesRepo.deleteEdge(edgeId);

      state.undoStack.push({
        type: 'delete',
        edge: edge,
        nodeA: na,
        nodeB: nb,
      });
      state.redoStack = [];

      if (state.selectedEdgeId === edgeId) state.selectedEdgeId = null;

      const summary = SM.nodesRepo.getStagedSummary();
      showToast(`🗑️ تم وسم المسار للحذف بالمسودة بين ${na ? na.name_ar : edge.node_id_a} و ${nb ? nb.name_ar : edge.node_id_b} [${summary.total} بالمسودة]`, 'info');
      
      updatePendingBadge();
      renderCanvas();
      renderNodeList();
      updateInspector();
    } catch (err) {
      console.error('[node-linker] Failed to delete edge:', err);
      showToast(`❌ تعذر حذف المسار: ${err.message || err}`, 'error');
    }
  }

  async function executeSplitEdge(edgeId, intermediateNodeId) {
    const edge = SM.nodesRepo.getEdges().find(e => String(e.edge_id) === String(edgeId));
    const nodeC = SM.nodesRepo.lookupById(intermediateNodeId);

    if (!edge || !nodeC) return;
    if (edge.node_id_a === nodeC.node_id || edge.node_id_b === nodeC.node_id) {
      showToast('⚠️ لا يمكن إدراج النقطة في مسار هي بالفعل أحد طرفيه', 'error');
      return;
    }

    const nodeA = SM.nodesRepo.lookupById(edge.node_id_a);
    const nodeB = SM.nodesRepo.lookupById(edge.node_id_b);

    try {
      const splitResult = await SM.nodesRepo.splitEdge(edgeId, intermediateNodeId);

      state.undoStack.push({
        type: 'split',
        deletedEdge: splitResult.deletedEdge,
        newEdges: splitResult.newEdges,
        nodeA,
        nodeB,
        nodeC,
      });
      state.redoStack = [];

      state.selectedNodeId = nodeC.node_id;
      state.selectedEdgeId = null;
      state.splitCandidateNodeId = null;
      state.splitCandidateEdgeId = null;

      const summary = SM.nodesRepo.getStagedSummary();
      showToast(`🎉 تم إدراج "${nodeC.name_ar}" بالمنتصف وتقسيم المسار لمسارين جديدين بالمسودة! [${summary.total} بالمسودة]`, 'success');
      
      updatePendingBadge();
      renderCanvas();
      renderNodeList();
      updateInspector();
      updateHelperBanner();
    } catch (err) {
      console.error('[node-linker] Split failed:', err);
      showToast(`❌ تعذر تقسيم المسار: ${err.message || err}`, 'error');
    }
  }

  // ── Undo & Redo ─────────────────────────────────────────────────────────────
  async function undo() {
    if (state.undoStack.length === 0) {
      showToast('لا توجد عمليات سابقة للتراجع عنها', 'info');
      return;
    }

    const action = state.undoStack.pop();

    try {
      if (action.type === 'create') {
        await SM.nodesRepo.deleteEdge(action.edge.edge_id);
        state.redoStack.push(action);
        showToast(`↶ تراجع: تم إلغاء المسار بين ${action.nodeA.name_ar} و ${action.nodeB.name_ar}`, 'info');
      } else if (action.type === 'delete') {
        const restored = await SM.nodesRepo.addEdge({
          nodeIdA: action.edge.node_id_a,
          nodeIdB: action.edge.node_id_b,
          distanceMeters: action.edge.distance_meters,
          kind: action.edge.kind,
          connectorName: action.edge.connector_name,
        });
        state.redoStack.push({ ...action, restoredEdge: restored });
        showToast(`↶ تراجع: تم استعادة المسار المحذوف`, 'info');
      } else if (action.type === 'split') {
        for (const ne of action.newEdges) {
          await SM.nodesRepo.deleteEdge(ne.edge_id);
        }
        await SM.nodesRepo.addEdge({
          nodeIdA: action.deletedEdge.node_id_a,
          nodeIdB: action.deletedEdge.node_id_b,
          distanceMeters: action.deletedEdge.distance_meters,
          kind: action.deletedEdge.kind,
          connectorName: action.deletedEdge.connector_name,
        });
        state.redoStack.push(action);
        showToast(`↶ تراجع: تم إلغاء تقسيم المسار واستعادة المسار الأصلي`, 'info');
      }

      updatePendingBadge();
      renderCanvas();
      renderNodeList();
      updateInspector();
    } catch (err) {
      console.error('[node-linker] Undo failed:', err);
      showToast(`❌ فشل التراجع: ${err.message || err}`, 'error');
    }
  }

  async function redo() {
    if (state.redoStack.length === 0) {
      showToast('لا توجد عمليات للإعادة', 'info');
      return;
    }

    const action = state.redoStack.pop();
    try {
      if (action.type === 'create') {
        await executeCreateEdge(action.edge.node_id_a, action.edge.node_id_b, action.edge.distance_meters, action.edge.kind);
      } else if (action.type === 'delete') {
        if (action.restoredEdge) {
          await executeDeleteEdge(action.restoredEdge.edge_id);
        }
      } else if (action.type === 'split') {
        const edge = SM.nodesRepo.getEdgeBetween(action.nodeA.node_id, action.nodeB.node_id);
        if (edge) {
          await executeSplitEdge(edge.edge_id, action.nodeC.node_id);
        }
      }
      updatePendingBadge();
    } catch (err) {
      console.error('[node-linker] Redo failed:', err);
    }
  }

  // ── Inspector & Details Panel ───────────────────────────────────────────────
  function updateInspector() {
    const card = $('inspectorCard');
    if (!card) return;

    // 1. If Node Selected
    if (state.selectedNodeId) {
      const node = SM.nodesRepo.lookupById(state.selectedNodeId);
      if (!node) return;

      const conns = SM.nodesRepo.getNeighborNodes(node.node_id);
      const isVertical = node.type === 'elevator' || node.type === 'stairs';

      let neighborsHtml = '';
      if (conns.length === 0) {
        neighborsHtml = `<div class="text-muted" style="font-size: 0.75rem;">لا توجد مسارات متصلة بهذه النقطة (نود منعزلة)</div>`;
      } else {
        neighborsHtml = conns.map(c => `
          <div class="neighbor-chip">
            <span><b>#${c.neighborId}</b> ${c.neighborNode ? c.neighborNode.name_ar : ''} (${c.edge.distance_meters}م)</span>
            <button class="neighbor-del-btn" data-edge-id="${c.edge.edge_id}" title="فك الارتباط / حذف هذا المسار">✕</button>
          </div>
        `).join('');
      }

      card.innerHTML = `
        <div class="panel-section-title">
          <span>📍</span>
          <span>بيانات النقطة #${node.node_id}</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">الاسم بالعربي:</span>
          <span class="prop-val">${node.name_ar || '—'}</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">الاسم بالإنجليزي:</span>
          <span class="prop-val">${node.name_en || '—'}</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">الدور (Level):</span>
          <span class="prop-val mono">${node.level_id || '—'}</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">النوع:</span>
          <span class="prop-val">${isVertical ? 'أسانسير / سلم (رأسي)' : (node.type || 'ممر')}</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">الإحداثيات (X, Y):</span>
          <div style="display: flex; gap: 4px; align-items: center;">
            <input type="number" id="nodeXInput" class="prop-input" style="width: 54px;" value="${node.x}" title="إحداثي X (شمال-جنوب)" />
            <span class="text-muted">,</span>
            <input type="number" id="nodeYInput" class="prop-input" style="width: 54px;" value="${node.y}" title="إحداثي Y (شرق-غرب)" />
            <button id="btnSaveNodeCoords" class="btn-icon-label" style="padding: 3px 6px;" title="حفظ تعديل الإحداثيات في Supabase">💾</button>
          </div>
        </div>

        <div class="prop-row">
          <span class="prop-label">المسارات المتصلة:</span>
          <span class="prop-val mono" style="color: ${conns.length > 0 ? '#3DDC84' : '#C97B6E'};">${conns.length} مسار</span>
        </div>

        <div style="margin-top: 8px;">
          <div class="prop-label" style="font-size: 0.75rem; margin-bottom: 6px; font-weight: 600;">النقاط المجاورة المتصلة:</div>
          <div class="neighbors-list">${neighborsHtml}</div>
        </div>

        <div class="quick-action-box">
          <div class="quick-action-title">
            <span>🔗</span>
            <span>توصيل سريع بنقطة أخرى:</span>
          </div>
          <div style="display: flex; gap: 6px;">
            <select id="quickConnectSelect" class="prop-select" style="flex: 1; width: auto; font-size: 0.76rem;">
              <option value="">-- اختر نقطة لتوصيلها --</option>
              ${getFloorNodes().filter(fn => fn.node_id !== node.node_id).map(fn => {
                const d = SM.nodesRepo.calculateDistance(node, fn);
                const exists = SM.nodesRepo.getEdgeBetween(node.node_id, fn.node_id);
                return `<option value="${fn.node_id}">${exists ? '✓ متصل: ' : ''}#${fn.node_id} ${fn.name_ar || fn.name_en || ''} (${d}م)</option>`;
              }).join('')}
            </select>
            <button id="btnQuickConnect" class="btn-primary-action" style="padding: 6px 12px; white-space: nowrap;">
              <span>🔗</span> ربط
            </button>
          </div>
        </div>

        <div class="card-actions-group">
          <button id="btnConnectFromThis" class="btn-primary-action">
            <span>👆</span> تحديد نقطة الربط بالماوس
          </button>
          <button id="btnSplitWithThis" class="btn-secondary-action">
            <span>✂️</span> إدراج في مسار مجاور
          </button>
          <button id="btnFocusNode" class="btn-secondary-action">
            <span>🎯</span> تركيز الكاميرا على النقطة
          </button>
        </div>
      `;

      // Quick Connect Button Listener
      const quickConnectBtn = $('btnQuickConnect');
      if (quickConnectBtn) {
        quickConnectBtn.addEventListener('click', async () => {
          const targetId = parseInt($('quickConnectSelect').value, 10);
          if (!targetId) {
            showToast('⚠️ يرجى اختيار نقطة من القائمة أولاً', 'error');
            return;
          }
          await executeCreateEdge(node.node_id, targetId);
        });
      }

      // Save node coordinates listener
      const saveCoordsBtn = $('btnSaveNodeCoords');
      if (saveCoordsBtn) {
        saveCoordsBtn.addEventListener('click', async () => {
          const nx = parseFloat($('nodeXInput').value);
          const ny = parseFloat($('nodeYInput').value);
          if (!isNaN(nx) && !isNaN(ny)) {
            try {
              const client = SM.nodesRepo.getClient();
              if (client) {
                await client.from('nodes').update({ x: nx, y: ny }).eq('node_id', node.node_id);
              }
              node.x = nx;
              node.y = ny;
              showToast(`✅ تم حفظ إحداثيات النقطة #${node.node_id} (X:${nx}, Y:${ny})`, 'success');
              renderCanvas();
              renderNodeList();
            } catch (err) {
              showToast('❌ تعذر حفظ الإحداثيات: ' + (err.message || err), 'error');
            }
          }
        });
      }

      // Event listeners for neighbor disconnect buttons
      card.querySelectorAll('.neighbor-del-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const eId = parseInt(btn.dataset.edgeId, 10);
          executeDeleteEdge(eId);
        });
      });

      $('btnConnectFromThis').addEventListener('click', () => {
        setMode('connect');
        state.connectStartNodeId = node.node_id;
        renderCanvas();
        updateHelperBanner();
        showToast(`اضغط الآن على النقطة الثانية لربطها بـ #${node.node_id}`, 'info');
      });

      $('btnSplitWithThis').addEventListener('click', () => {
        setMode('split');
        state.splitCandidateNodeId = node.node_id;
        renderCanvas();
        updateHelperBanner();
        showToast(`اضغط الآن على المسار المراد إدراج #${node.node_id} في منتصفه`, 'info');
      });

      $('btnFocusNode').addEventListener('click', () => {
        centerOnNode(node);
      });

      return;
    }

    // 2. If Edge Selected
    if (state.selectedEdgeId) {
      const edge = SM.nodesRepo.getEdges().find(e => Number(e.edge_id) === Number(state.selectedEdgeId));
      if (!edge) return;

      const na = SM.nodesRepo.lookupById(edge.node_id_a);
      const nb = SM.nodesRepo.lookupById(edge.node_id_b);

      const splitCandidates = getFloorNodes().filter(fn => 
        Number(fn.node_id) !== Number(edge.node_id_a) && 
        Number(fn.node_id) !== Number(edge.node_id_b)
      );

      card.innerHTML = `
        <div class="panel-section-title">
          <span>📏</span>
          <span>بيانات المسار #${edge.edge_id}</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">النقطة الأولى (A):</span>
          <span class="prop-val">#${edge.node_id_a} (${na ? na.name_ar : '—'})</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">النقطة الثانية (B):</span>
          <span class="prop-val">#${edge.node_id_b} (${nb ? nb.name_ar : '—'})</span>
        </div>

        <div class="prop-row">
          <span class="prop-label">الطول (بالمتر):</span>
          <input type="number" id="edgeDistInput" class="prop-input" step="0.5" value="${edge.distance_meters || ''}" />
        </div>

        <div class="prop-row">
          <span class="prop-label">نوع المسار:</span>
          <select id="edgeKindSelect" class="prop-select">
            <option value="walk" ${edge.kind === 'walk' ? 'selected' : ''}>ممر مشاة (walk)</option>
            <option value="stairs" ${edge.kind === 'stairs' ? 'selected' : ''}>سلم (stairs)</option>
            <option value="elevator" ${edge.kind === 'elevator' ? 'selected' : ''}>أسانسير (elevator)</option>
          </select>
        </div>

        <div class="prop-row">
          <span class="prop-label">اسم الممر / الرابط:</span>
          <input type="text" id="edgeConnectorInput" class="prop-input" style="width: 140px; text-align: left;" value="${edge.connector_name || ''}" placeholder="الممر الدائري" />
        </div>

        <div class="quick-action-box">
          <div class="quick-action-title">
            <span>✂️</span>
            <span>إدراج نقطة في منتصف المسار (تقسيم):</span>
          </div>
          <div style="display: flex; gap: 6px;">
            <select id="quickSplitSelect" class="prop-select" style="flex: 1; width: auto; font-size: 0.76rem;">
              <option value="">-- اختر نقطة لتوضع بالمنتصف --</option>
              ${splitCandidates.map(cn => `
                <option value="${cn.node_id}">#${cn.node_id} ${cn.name_ar || cn.name_en || ''}</option>
              `).join('')}
            </select>
            <button id="btnQuickSplit" class="btn-secondary-action" style="padding: 6px 12px; border-color: var(--brand-primary); color: var(--brand-light); white-space: nowrap;">
              <span>✂️</span> إدراج
            </button>
          </div>
        </div>

        <div class="card-actions-group">
          <button id="btnSaveEdge" class="btn-primary-action">
            <span>💾</span> حفظ التعديلات
          </button>
          <button id="btnRecalcDist" class="btn-secondary-action">
            <span>📐</span> إعادة حساب المسافة هندسياً
          </button>
          <button id="btnSplitEdgePrompt" class="btn-secondary-action">
            <span>👆</span> تحديد نقطة الإدراج بالماوس
          </button>
          <button id="btnDeleteEdgeCard" class="btn-danger-action">
            <span>🗑️</span> حذف المسار نهائياً
          </button>
        </div>
      `;

      // Quick Split Button
      const quickSplitBtn = $('btnQuickSplit');
      if (quickSplitBtn) {
        quickSplitBtn.addEventListener('click', async () => {
          const targetId = parseInt($('quickSplitSelect').value, 10);
          if (!targetId) {
            showToast('⚠️ يرجى اختيار نقطة من القائمة أولاً', 'error');
            return;
          }
          await executeSplitEdge(edge.edge_id, targetId);
        });
      }

      $('btnSaveEdge').addEventListener('click', async () => {
        const dist = parseFloat($('edgeDistInput').value);
        const kind = $('edgeKindSelect').value;
        const connName = $('edgeConnectorInput').value.trim() || null;

        try {
          await SM.nodesRepo.updateEdge(edge.edge_id, {
            distance_meters: isNaN(dist) ? null : dist,
            kind: kind,
            connector_name: connName,
          });
          const summary = SM.nodesRepo.getStagedSummary();
          showToast(`✏️ تم حفظ خصائص المسار في المسودة [${summary.total} تعديل بالمسودة]`, 'success');
          updatePendingBadge();
          renderCanvas();
        } catch (err) {
          showToast('❌ تعذر حفظ التعديلات: ' + (err.message || err), 'error');
        }
      });

      $('btnRecalcDist').addEventListener('click', () => {
        const d = SM.nodesRepo.calculateDistance(na, nb);
        $('edgeDistInput').value = d;
        showToast(`📐 المسافة الهندسية المحسوبة: ${d} متر`, 'info');
      });

      $('btnSplitEdgePrompt').addEventListener('click', () => {
        setMode('split');
        state.splitCandidateEdgeId = edge.edge_id;
        showToast(`المسار #${edge.edge_id} محدد للتقسيم — اضغط الآن على النقطة المراد وضعها في المنتصف`, 'info');
        renderCanvas();
        updateHelperBanner();
      });

      $('btnDeleteEdgeCard').addEventListener('click', () => {
        executeDeleteEdge(edge.edge_id);
      });

      return;
    }

    // 3. If Nothing Selected: Overview Statistics
    const floorNodes = getFloorNodes();
    const floorEdges = getFloorEdges();
    const isolatedNodes = floorNodes.filter(n => {
      const conns = (SM.nodesRepo && typeof SM.nodesRepo.getConnectedEdges === 'function') 
        ? SM.nodesRepo.getConnectedEdges(n.node_id) 
        : [];
      return conns.length === 0;
    });

    card.innerHTML = `
      <div class="panel-section-title">
        <span>📊</span>
        <span>إحصائيات الدور ${state.activeFloor}</span>
      </div>

      <div class="prop-row">
        <span class="prop-label">إجمالي النقاط:</span>
        <span class="prop-val mono">${floorNodes.length}</span>
      </div>

      <div class="prop-row">
        <span class="prop-label">المسارات الحالية:</span>
        <span class="prop-val mono text-success">${floorEdges.length} مسار</span>
      </div>

      <div class="prop-row">
        <span class="prop-label">نقاط غير متصلة (منعزلة):</span>
        <span class="prop-val mono" style="color: ${isolatedNodes.length > 0 ? '#C97B6E' : '#3DDC84'};">${isolatedNodes.length}</span>
      </div>

      <div class="inspector-empty" style="margin-top: 10px;">
        <span class="empty-icon">🖱️</span>
        <span>اضغط على أي نقطة أو مسار بالماوس لمعاينة وتعديل الخصائص</span>
      </div>
    `;
  }

  // ── Left Sidebar Node List ──────────────────────────────────────────────────
  function renderNodeList() {
    const listEl = $('nodesScrollList');
    if (!listEl) return;

    const nodes = getFloorNodes();
    $('nodesCountHeader').textContent = `${nodes.length} نقطة`;

    if (nodes.length === 0) {
      listEl.innerHTML = `<div class="inspector-empty">لا توجد نقاط مطابقة للبحث أو الفلتر</div>`;
      return;
    }

    listEl.innerHTML = nodes.map(node => {
      const conns = (SM.nodesRepo && typeof SM.nodesRepo.getConnectedEdges === 'function') 
        ? SM.nodesRepo.getConnectedEdges(node.node_id) 
        : [];
      const isSelected = state.selectedNodeId === node.node_id;
      const isIsolated = conns.length === 0;

      return `
        <div class="node-list-item ${isSelected ? 'selected' : ''}" data-node-id="${node.node_id}">
          <div class="node-item-info">
            <span class="node-item-title">
              <span>${node.name_ar || node.name_en || 'نقطة ممر'}</span>
            </span>
            <span class="node-item-meta">#${node.node_id} | X:${node.x} Y:${node.y}</span>
          </div>
          <span class="node-conn-badge ${isIsolated ? 'zero' : 'connected'}">
            ${conns.length} مسار
          </span>
        </div>
      `;
    }).join('');

    listEl.querySelectorAll('.node-list-item').forEach(el => {
      el.addEventListener('click', () => {
        const id = parseInt(el.dataset.nodeId, 10);
        const node = SM.nodesRepo.lookupById(id);
        if (node) {
          handleNodeClick(node);
          centerOnNode(node);
        }
      });
    });
  }

  // ── Helper Banner Instructions ──────────────────────────────────────────────
  function updateHelperBanner() {
    const banner = $('helperBanner');
    if (!banner) return;

    let icon = 'ℹ️';
    let text = 'اضغط على أي نقطة أو مسار بالماوس للاختيار والمعاينة';
    let highlight = false;

    if (state.activeMode === 'connect') {
      icon = '🔗';
      if (!state.connectStartNodeId) {
        text = 'وضع الربط: اضغط على النقطة الأولى لبدء المسار';
      } else {
        const na = SM.nodesRepo.lookupById(state.connectStartNodeId);
        text = `تم اختيار #${state.connectStartNodeId} (${na ? na.name_ar : ''}) — اضغط على النقطة الثانية لإتمام الربط!`;
        highlight = true;
      }
    } else if (state.activeMode === 'split') {
      icon = '✂️';
      if (!state.splitCandidateNodeId && !state.splitCandidateEdgeId) {
        text = 'وضع التقسيم: اضغط على النقطة ثم اضغط على المسار (أو العكس) لإدراجها في منتصفه';
      } else if (state.splitCandidateNodeId && !state.splitCandidateEdgeId) {
        const nc = SM.nodesRepo.lookupById(state.splitCandidateNodeId);
        text = `تم اختيار النقطة #${state.splitCandidateNodeId} (${nc ? nc.name_ar : ''}) — اضغط على المسار المراد وضعها في منتصفه`;
        highlight = true;
      } else if (state.splitCandidateEdgeId && !state.splitCandidateNodeId) {
        text = `تم اختيار المسار #${state.splitCandidateEdgeId} — اضغط على النقطة المراد وضعها في منتصفه`;
        highlight = true;
      }
    } else if (state.activeMode === 'delete') {
      icon = '🗑️';
      text = 'وضع الحذف: اضغط على أي مسار بالماوس لحذفه نهائياً';
      highlight = true;
    } else {
      if (state.selectedNodeId && state.hoveredEdgeId) {
        const nc = SM.nodesRepo.lookupById(state.selectedNodeId);
        text = `✂️ اضغط لإدراج النقطة #${state.selectedNodeId} (${nc ? nc.name_ar : ''}) في هذا المسار!`;
        icon = '✂️';
        highlight = true;
      } else if (state.selectedNodeId) {
        const n = SM.nodesRepo.lookupById(state.selectedNodeId);
        text = `محدد: #${state.selectedNodeId} (${n ? n.name_ar : ''}) | اضغط على مسار لإدراجها فيه، أو زر الربط لتوصيلها`;
      } else if (state.selectedEdgeId) {
        text = `محدد المسار #${state.selectedEdgeId} | اضغط على أي نقطة لإدراجها في منتصفه، أو زر الحذف لإزالته`;
      }
    }

    banner.innerHTML = `<span class="helper-icon">${icon}</span><span>${text}</span>`;
    banner.classList.toggle('highlight', highlight);
  }

  // ── Pending Changes Badge & Sync State ──────────────────────────────────────
  function updatePendingBadge() {
    if (!window.SM || !SM.nodesRepo) return;
    const summary = SM.nodesRepo.getStagedSummary();
    const countBadge = $('pendingChangesCount');
    const saveBtn = $('btnSaveBatchToDb');
    const discardBtn = $('btnDiscardChanges');
    const syncBadge = $('syncStatusBadge');
    const syncDot = $('syncDot');
    const syncText = $('syncText');

    if (countBadge) {
      countBadge.textContent = summary.total;
    }

    if (saveBtn) {
      if (summary.total > 0) {
        saveBtn.classList.remove('disabled');
        saveBtn.removeAttribute('disabled');
        saveBtn.title = `توجد ${summary.total} تعديلات معلقة (+${summary.addedCount} مسار جديد، -${summary.deletedCount} محذوف، ~${summary.updatedCount} معدل) — اضغط لحفظها دفعة واحدة في Supabase`;
      } else {
        saveBtn.classList.add('disabled');
        saveBtn.setAttribute('disabled', 'true');
        saveBtn.title = 'لا توجد تعديلات غير محفوظة حالياً';
      }
    }

    if (discardBtn) {
      discardBtn.style.display = summary.total > 0 ? 'inline-flex' : 'none';
    }

    if (syncBadge && syncDot && syncText) {
      if (summary.total > 0) {
        syncBadge.classList.add('pending');
        syncDot.className = 'sync-dot pending';
        syncText.textContent = `${summary.total} في المسودة (غير محفوظ)`;
        syncBadge.title = `لديك مسارات وتعديلات قيد المعاينة محلياً لم تُرفع للسيرفر بعد (+${summary.addedCount}، -${summary.deletedCount})`;
      } else {
        syncBadge.classList.remove('pending');
        syncDot.className = 'sync-dot';
        syncText.textContent = 'متزامن مع السيرفر';
        syncBadge.title = 'جميع المسارات والتعديلات متزامنة مع Supabase';
      }
    }
  }

  // ── Mode Switching ──────────────────────────────────────────────────────────
  function setMode(mode) {
    state.activeMode = mode;
    state.connectStartNodeId = null;
    state.splitCandidateNodeId = null;
    state.splitCandidateEdgeId = null;

    document.querySelectorAll('.mode-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.mode === mode);
    });

    if (svgRoot) {
      svgRoot.classList.remove('connecting', 'splitting', 'deleting');
      if (mode === 'connect') svgRoot.classList.add('connecting');
      if (mode === 'split') svgRoot.classList.add('splitting');
      if (mode === 'delete') svgRoot.classList.add('deleting');
    }

    renderCanvas();
    updateHelperBanner();
  }

  function clearSelection() {
    state.selectedNodeId = null;
    state.selectedEdgeId = null;
    state.connectStartNodeId = null;
    state.splitCandidateNodeId = null;
    state.splitCandidateEdgeId = null;
    renderCanvas();
    renderNodeList();
    updateInspector();
    updateHelperBanner();
  }

  // ── Pan, Zoom & Camera Centering ────────────────────────────────────────────
  function setupPanZoom() {
    const container = $('canvasViewport');
    if (!container) return;

    let hasDragged = false;

    container.addEventListener('mousedown', (e) => {
      const isBg = e.target.id === 'canvasBgHit' || e.target === svgRoot;
      if (isBg || e.button === 1 || e.button === 2) {
        state.panZoom.isPanning = true;
        hasDragged = false;
        state.panZoom.startX = e.clientX;
        state.panZoom.startY = e.clientY;
        state.panZoom.startPanX = state.panZoom.panX;
        state.panZoom.startPanY = state.panZoom.panY;
      }
    });

    window.addEventListener('mousemove', (e) => {
      // Update mouse coordinate in SVG viewBox space for preview line
      if (svgRoot) {
        const pt = svgRoot.createSVGPoint();
        pt.x = e.clientX;
        pt.y = e.clientY;
        const ctm = svgRoot.getScreenCTM();
        if (ctm) {
          const svgP = pt.matrixTransform(ctm.inverse());
          state.mouseCoord.x = svgP.x;
          state.mouseCoord.y = svgP.y;
          if (state.activeMode === 'connect' && state.connectStartNodeId) {
            renderPreview();
          }
        }
      }

      if (!state.panZoom.isPanning) return;
      const dxRaw = Math.abs(e.clientX - state.panZoom.startX);
      const dyRaw = Math.abs(e.clientY - state.panZoom.startY);
      if (dxRaw > 3 || dyRaw > 3) {
        hasDragged = true;
        svgRoot.classList.add('panning');
      }

      const scaleRatio = ((state.floorSpan || 1800) / (svgRoot.clientWidth || 1000)) / (state.panZoom.zoom || 1);
      const dx = (e.clientX - state.panZoom.startX) * scaleRatio;
      const dy = (e.clientY - state.panZoom.startY) * scaleRatio;
      state.panZoom.panX = state.panZoom.startPanX + dx;
      state.panZoom.panY = state.panZoom.startPanY + dy;
      updateViewBox();
    });

    window.addEventListener('mouseup', () => {
      if (state.panZoom.isPanning) {
        state.panZoom.isPanning = false;
        svgRoot.classList.remove('panning');
      }
    });

    container.addEventListener('wheel', (e) => {
      e.preventDefault();
      const factor = e.deltaY < 0 ? 1.15 : 0.85;
      zoom(factor);
    }, { passive: false });

    svgRoot.addEventListener('click', (e) => {
      if (hasDragged) return;
      if (e.target.id === 'canvasBgHit' || e.target === svgRoot) {
        clearSelection();
      }
    });
  }

  function updateViewBox() {
    if (!svgRoot) return;
    const z = state.panZoom.zoom || 1.0;
    const baseSpan = state.floorSpan || 1800;
    const vbW = baseSpan / z;
    const vbH = baseSpan / z;

    const cx = state.panZoom.centerX || 1200;
    const cy = state.panZoom.centerY || 1200;
    const vbX = cx - (vbW / 2) - state.panZoom.panX;
    const vbY = cy - (vbH / 2) - state.panZoom.panY;

    svgRoot.setAttribute('viewBox', `${vbX} ${vbY} ${vbW} ${vbH}`);
  }

  function zoom(factor) {
    state.panZoom.zoom = Math.min(Math.max(state.panZoom.zoom * factor, 0.4), 8.0);
    updateViewBox();
  }

  function fitFloorToView() {
    const nodes = getFloorNodes();
    if (nodes.length === 0) {
      resetCamera();
      return;
    }

    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    for (const n of nodes) {
      const nx = Number(n.x);
      const ny = Number(n.y);
      minX = Math.min(minX, nx);
      maxX = Math.max(maxX, nx);
      minY = Math.min(minY, ny);
      maxY = Math.max(maxY, ny);
    }

    const minScreenX = PAD + minY * BASE_SCALE;
    const maxScreenX = PAD + maxY * BASE_SCALE;
    const minScreenY = PAD + minX * BASE_SCALE;
    const maxScreenY = PAD + maxX * BASE_SCALE;

    state.panZoom.centerX = (minScreenX + maxScreenX) / 2;
    state.panZoom.centerY = (minScreenY + maxScreenY) / 2;
    state.panZoom.panX = 0;
    state.panZoom.panY = 0;
    state.panZoom.zoom = 1.0;

    const spanW = maxScreenX - minScreenX;
    const spanH = maxScreenY - minScreenY;
    state.floorSpan = Math.max(spanW, spanH) + 240;

    updateViewBox();
  }

  function centerOnNode(node) {
    const pt = toScreenCoords(node);
    if (!pt) return;

    state.panZoom.centerX = pt.x;
    state.panZoom.centerY = pt.y;
    state.panZoom.panX = 0;
    state.panZoom.panY = 0;
    state.panZoom.zoom = 2.4;
    updateViewBox();
  }

  function resetCamera() {
    fitFloorToView();
  }

  async function loadBackupAndRender() {
    showToast('جاري تحميل بيانات النسخة الاحتياطية...', 'info');
    await SM.nodesRepo.loadLocalFallback();
    const allNodes = SM.nodesRepo.getAllNodes();
    const allLevels = SM.nodesRepo.getLevels();
    const floorsWithNodes = allLevels.filter(lvl => 
      allNodes.some(n => n.level_id === lvl.level_id)
    );
    if (floorsWithNodes.length > 0) {
      const hasL4 = floorsWithNodes.find(l => l.level_id === 'L4');
      state.activeFloor = hasL4 ? 'L4' : floorsWithNodes[0].level_id;
    }
    renderFloorTabs();
    renderNodeList();
    renderCanvas();
    fitFloorToView();
    updateInspector();
    showToast(`✅ تم استرجاع ${allNodes.length} نقطة بنجاح`, 'success');
  }

  // ── Keyboard Shortcuts ──────────────────────────────────────────────────────
  function setupKeyboardShortcuts() {
    window.addEventListener('keydown', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') {
        return;
      }

      if (e.key === 'Escape') {
        clearSelection();
        setMode('select');
      } else if (e.key === '1' || e.key === 's' || e.key === 'S') {
        setMode('select');
      } else if (e.key === '2' || e.key === 'c' || e.key === 'C') {
        setMode('connect');
      } else if (e.key === '3' || e.key === 'i' || e.key === 'I') {
        setMode('split');
      } else if (e.key === '4' || e.key === 'd' || e.key === 'D') {
        setMode('delete');
      } else if (e.key === 'Delete' || e.key === 'Backspace') {
        if (state.selectedEdgeId) {
          executeDeleteEdge(state.selectedEdgeId);
        }
      } else if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
        e.preventDefault();
        if (e.shiftKey) redo();
        else undo();
      } else if ((e.ctrlKey || e.metaKey) && e.key === 'y') {
        e.preventDefault();
        redo();
      }
    });
  }

  // ── UI Events Setup ─────────────────────────────────────────────────────────
  function setupEventListeners() {
    document.querySelectorAll('.mode-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        setMode(btn.dataset.mode);
      });
    });

    $('btnUndo').addEventListener('click', undo);
    $('btnRedo').addEventListener('click', redo);

    $('btnZoomIn').addEventListener('click', () => zoom(1.25));
    $('btnZoomOut').addEventListener('click', () => zoom(0.8));
    $('btnFitView').addEventListener('click', fitFloorToView);
    $('btnResetView').addEventListener('click', resetCamera);

    $('btnToggleLabels').addEventListener('click', () => {
      state.viewOptions.showLabels = !state.viewOptions.showLabels;
      $('btnToggleLabels').classList.toggle('active', state.viewOptions.showLabels);
      renderCanvas();
    });

    $('btnToggleLengths').addEventListener('click', () => {
      state.viewOptions.showLengths = !state.viewOptions.showLengths;
      $('btnToggleLengths').classList.toggle('active', state.viewOptions.showLengths);
      renderCanvas();
    });

    $('nodeSearchInput').addEventListener('input', (e) => {
      state.searchQuery = e.target.value;
      renderNodeList();
    });

    $('filterAllNodes').addEventListener('click', () => {
      state.viewOptions.filterIsolated = false;
      $('filterAllNodes').classList.add('active');
      $('filterIsolatedNodes').classList.remove('active');
      renderNodeList();
      renderCanvas();
    });

    $('filterIsolatedNodes').addEventListener('click', () => {
      state.viewOptions.filterIsolated = true;
      $('filterIsolatedNodes').classList.add('active');
      $('filterAllNodes').classList.remove('active');
      renderNodeList();
      renderCanvas();
    });

    $('btnRefreshDb').addEventListener('click', async () => {
      if (SM.nodesRepo && SM.nodesRepo.hasStagedChanges()) {
        const conf = window.confirm('تنبيه: لديك تعديلات ومسارات بالمسودة لم تُحفظ في السيرفر بعد. هل تريد المتابعة وإعادة التحميل وفقدان هذه التعديلات؟');
        if (!conf) return;
      }
      showToast('🔄 جاري تحديث البيانات من Supabase...', 'info');
      await SM.nodesRepo.refresh();
      state.undoStack = [];
      state.redoStack = [];
      updatePendingBadge();
      renderFloorTabs();
      renderNodeList();
      renderCanvas();
      fitFloorToView();
      updateInspector();
      showToast('✅ تم تحديث البيانات بنجاح', 'success');
    });

    // ── Batch Save to Supabase (Single-Request Bulk Commit) ─────────────────
    $('btnSaveBatchToDb').addEventListener('click', async () => {
      if (!SM.nodesRepo || !SM.nodesRepo.hasStagedChanges()) {
        showToast('ℹ️ لا توجد تعديلات غير محفوظة حالياً', 'info');
        return;
      }

      const summary = SM.nodesRepo.getStagedSummary();
      const saveText = $('btnSaveBatchText');
      const saveBtn = $('btnSaveBatchToDb');
      const originalText = saveText ? saveText.textContent : 'حفظ التغييرات في السيرفر';

      try {
        if (saveBtn) {
          saveBtn.classList.add('disabled');
          saveBtn.setAttribute('disabled', 'true');
        }
        if (saveText) {
          saveText.textContent = `جاري الحفظ في السيرفر (${summary.total} تعديل)...`;
        }
        showToast(`⏳ جاري رفع وحفظ كافة المسارات والتعديلات دفعة واحدة في Supabase (+${summary.addedCount}، -${summary.deletedCount})...`, 'info');

        const result = await SM.nodesRepo.commitStagedChanges();

        state.undoStack = [];
        state.redoStack = [];

        updatePendingBadge();
        renderCanvas();
        renderNodeList();
        updateInspector();

        showToast(`🎉 تم الحفظ بنجاح في السيرفر! تم اعتماد ${result.added} مسار جديد وحذف ${result.deleted} مسار بطلب واحد.`, 'success');
      } catch (err) {
        console.error('[node-linker] Bulk commit failed:', err);
        showToast(`❌ تعذر حفظ التغييرات في السيرفر: ${err.message || err}`, 'error');
      } finally {
        if (saveText) saveText.textContent = originalText;
        updatePendingBadge();
      }
    });

    // ── Discard Staged Changes ──────────────────────────────────────────────
    $('btnDiscardChanges').addEventListener('click', () => {
      if (!SM.nodesRepo) return;
      const summary = SM.nodesRepo.getStagedSummary();
      if (summary.total === 0) return;

      const confirmed = window.confirm(`هل أنت متأكد من إلغاء ${summary.total} تعديل غير محفوظ والعودة لآخر نسخة على السيرفر؟`);
      if (!confirmed) return;

      SM.nodesRepo.discardStagedChanges();
      state.undoStack = [];
      state.redoStack = [];
      state.selectedEdgeId = null;
      state.selectedNodeId = null;

      updatePendingBadge();
      renderCanvas();
      renderNodeList();
      updateInspector();
      showToast('↺ تم إلغاء كافة التعديلات غير المحفوظة والعودة للنسخة الأصلية', 'info');
    });

    // ── Warn before navigating away if there are unsaved staged changes ───────
    window.addEventListener('beforeunload', (e) => {
      if (window.SM && SM.nodesRepo && SM.nodesRepo.hasStagedChanges()) {
        e.preventDefault();
        e.returnValue = 'لديك تعديلات ومسارات غير محفوظة في السيرفر، هل أنت متأكد من المغادرة؟';
        return e.returnValue;
      }
    });

    $('btnExportJson').addEventListener('click', () => {
      const edges = SM.nodesRepo.getEdges();
      const nodes = SM.nodesRepo.getAllNodes();
      const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify({ nodes, edges }, null, 2));
      const a = document.createElement('a');
      a.setAttribute('href', dataStr);
      a.setAttribute('download', `ips_graph_backup_${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(a);
      a.click();
      a.remove();
      showToast('💾 تم تصدير نسخة من بيانات الشبكة بنجاح', 'success');
    });
  }

  // ── Toast Notifications ─────────────────────────────────────────────────────
  function showToast(message, type = 'info') {
    const container = $('toastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    let icon = 'ℹ️';
    if (type === 'success') icon = '✅';
    if (type === 'error') icon = '❌';

    toast.innerHTML = `
      <span>${icon}</span>
      <span>${message}</span>
    `;

    if (state.undoStack.length > 0 && type === 'success') {
      const undoBtn = document.createElement('button');
      undoBtn.className = 'toast-undo-btn';
      undoBtn.textContent = 'تراجع ↶';
      undoBtn.addEventListener('click', () => {
        undo();
        if (toast.remove) toast.remove();
        else if (toast.parentNode) toast.parentNode.removeChild(toast);
      });
      toast.appendChild(undoBtn);
    }

    container.appendChild(toast);

    setTimeout(() => {
      if (toast && toast.style) {
        toast.style.transition = 'opacity 0.3s, transform 0.3s';
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(10px)';
      }
      setTimeout(() => {
        if (toast && toast.remove) toast.remove();
        else if (toast && toast.parentNode) toast.parentNode.removeChild(toast);
      }, 300);
    }, 4500);
  }

  function isReady() {
    return isInitialized;
  }

  return {
    init,
    setFloor,
    setMode,
    undo,
    redo,
    fitFloorToView,
    resetCamera,
    showToast,
    loadBackupAndRender,
    isReady,
  };
})();

// Auto-bootstrap safely whether DOM is already loaded or still loading
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    if (window.NL) window.NL.init();
  });
} else {
  setTimeout(() => {
    if (window.NL) window.NL.init();
  }, 10);
}
