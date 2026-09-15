// dashboard.js — يربط كل الـmodules ببعض ويتحكم في الـUI الكامل.
// ترتيب التحميل في index.html:
//   config.js → auth.js → serial.js → nodes-repo.js → ota.js → dashboard.js

window.SM = window.SM || {};

SM.dashboard = (function () {
  // ── State ──────────────────────────────────────────────────────────────
  // Map<nodeIdHex, { nodeIdHex, hopCount, status, fwMajor, fwMinor,
  //                  lastSeenTime, timeoutMs, meta }>
  const nodeTable = new Map();

  // إصدار الفيرموير المستهدف (يكتبه الأدمن في حقل OTA)
  let targetFwMajor = null;
  let targetFwMinor = null;

  // ── DOM refs ────────────────────────────────────────────────────────────
  const $ = (id) => document.getElementById(id);

  // ── Helpers ─────────────────────────────────────────────────────────────
  function appendLog(text, type = "info") {
    const box = $("logConsole");
    if (!box) return;
    const line = document.createElement("div");
    line.className = "log-line " + type;
    line.textContent =
      "[" + new Date().toLocaleTimeString("en-US", { hour12: false }) + "] " + text;
    box.appendChild(line);
    box.scrollTop = box.scrollHeight;
  }

  function fmtVersion(major, minor) {
    if (major === null || major === undefined) return "—";
    return "v" + major + "." + (minor !== null && minor !== undefined ? minor : "?");
  }

  function fwBadgeClass(major, minor) {
    if (major === null || major === undefined) return "unknown";
    if (targetFwMajor === null) return "unknown";
    if (major === targetFwMajor && minor === targetFwMinor) return "current";
    return "old";
  }

  // ── Node record update (called by serial.onHealthLine) ──────────────────
  function onHealthData(nodeIdHex, hopCount, status, fwMajor, fwMinor) {
    const now = Date.now();
    const timeoutMs =
      SM.config.HEALTH_BASE_TIMEOUT_MS + hopCount * SM.config.HEALTH_PER_HOP_MARGIN_MS;
    const isExplicitOffline = status === "offline";
    const meta = SM.nodesRepo.lookup(nodeIdHex);

    nodeTable.set(nodeIdHex, {
      nodeIdHex,
      hopCount,
      status,
      fwMajor,
      fwMinor,
      lastSeenTime: isExplicitOffline ? now - timeoutMs - 1000 : now,
      timeoutMs,
      meta,
    });

    renderTable();
  }

  // ── Render ───────────────────────────────────────────────────────────────
  function renderTable() {
    const tbody = $("nodesTableBody");
    if (!tbody) return;

    const now = Date.now();
    const records = Array.from(nodeTable.values());

    if (records.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="6" class="empty-state">في انتظار أول heartbeat من بوردة Root...</td></tr>';
      updateStats(0, 0, 0, 0, 0);
      return;
    }

    records.sort((a, b) => a.nodeIdHex.localeCompare(b.nodeIdHex));

    let onlineCount = 0,
      offlineCount = 0,
      maxHop = 0,
      updatedCount = 0;

    tbody.innerHTML = records
      .map((r) => {
        const elapsed = now - r.lastSeenTime;
        const isOnline = elapsed <= r.timeoutMs;
        const secsAgo = Math.max(0, Math.round(elapsed / 1000));
        const badgeCls = fwBadgeClass(r.fwMajor, r.fwMinor);

        if (isOnline) onlineCount++;
        else offlineCount++;
        if (r.hopCount > maxHop) maxHop = r.hopCount;
        if (badgeCls === "current") updatedCount++;

        const nameCell = r.meta
          ? `<div class="node-name">${r.meta.name_ar || r.meta.name_en || "—"}</div>
             <div class="node-uuid">${r.nodeIdHex}</div>`
          : `<div class="node-uuid">${r.nodeIdHex}</div>`;

        return `<tr class="node-row ${isOnline ? "" : "offline"}">
          <td>
            <span class="status-badge ${isOnline ? "on" : "off"}">
              <span class="dot ${isOnline ? "on" : "off"}"></span>
              ${isOnline ? "نشط" : "مقطوع"}
            </span>
          </td>
          <td>${nameCell}</td>
          <td style="text-align:center"><span class="hop-badge">Hop ${r.hopCount}</span></td>
          <td style="text-align:center"><span class="fw-badge ${badgeCls}">${fmtVersion(r.fwMajor, r.fwMinor)}</span></td>
          <td style="text-align:center">${secsAgo}s</td>
          <td style="text-align:center;color:var(--muted)">${(r.timeoutMs / 1000).toFixed(1)}s</td>
        </tr>`;
      })
      .join("");

    updateStats(records.length, onlineCount, offlineCount, maxHop, updatedCount);

    const lu = $("lastUpdate");
    if (lu) lu.textContent = "آخر تحديث: " + new Date().toLocaleTimeString("ar-EG");
  }

  function updateStats(total, online, offline, hops, updated) {
    const set = (id, v) => { const el = $(id); if (el) el.textContent = v; };
    set("statTotal", total);
    set("statOnline", online);
    set("statOffline", offline);
    set("statHops", hops);
    set("statUpdated",
      targetFwMajor !== null ? updated + " / " + total : "—");
  }

  // ── Serial connection UI ─────────────────────────────────────────────────
  function setupSerialUI() {
    const connectBtn = $("connectBtn");
    const disconnectBtn = $("disconnectBtn");

    if (connectBtn) {
      connectBtn.addEventListener("click", async () => {
        try {
          await SM.serial.connect();
        } catch (e) {
          appendLog("فشل الاتصال: " + e.message, "error");
        }
      });
    }

    if (disconnectBtn) {
      disconnectBtn.addEventListener("click", async () => {
        await SM.serial.disconnect();
      });
    }

    SM.serial.onConnectionChange((connected) => {
      if (connectBtn) connectBtn.style.display = connected ? "none" : "inline-flex";
      if (disconnectBtn) disconnectBtn.style.display = connected ? "inline-flex" : "none";
      appendLog(connected ? "✅ اتصل بـRoot Serial" : "🔌 قُطع الاتصال", connected ? "info" : "warn");
      if (connected) SM.nodesRepo.refresh();
    });

    SM.serial.onHealthLine(onHealthData);
    SM.serial.onRawLine((line) => appendLog(line, "info"));
  }

  // ── Auth UI ──────────────────────────────────────────────────────────────
  function setupAuthUI() {
    const loginBtn = $("loginBtn");
    const logoutBtn = $("logoutBtn");
    const userEmailEl = $("userEmail");
    const loginModal = $("loginModal");
    const loginForm = $("loginForm");
    const loginError = $("loginError");
    const otaCard = $("otaCard");

    SM.auth.onChange(({ user, role }) => {
      const isAdmin = role === "admin";
      if (userEmailEl) userEmailEl.textContent = user ? user.email : "";
      if (loginBtn) loginBtn.style.display = user ? "none" : "inline-flex";
      if (logoutBtn) logoutBtn.style.display = user ? "inline-flex" : "none";
      if (otaCard) otaCard.style.display = isAdmin ? "block" : "none";
    });

    if (loginBtn) {
      loginBtn.addEventListener("click", () => {
        if (loginModal) loginModal.classList.add("open");
      });
    }

    if (logoutBtn) {
      logoutBtn.addEventListener("click", async () => {
        await SM.auth.signOut();
        appendLog("تم تسجيل الخروج", "warn");
      });
    }

    if (loginForm) {
      loginForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        if (loginError) loginError.style.display = "none";
        const email = loginForm.querySelector("#loginEmail").value.trim();
        const pass = loginForm.querySelector("#loginPass").value;
        try {
          await SM.auth.signIn(email, pass);
          if (loginModal) loginModal.classList.remove("open");
          appendLog("✅ تم تسجيل الدخول كـ " + email, "info");
        } catch (err) {
          if (loginError) {
            loginError.textContent = err.message;
            loginError.style.display = "block";
          }
        }
      });
    }

    // إغلاق الـmodal لو ضغط خارجه
    if (loginModal) {
      loginModal.addEventListener("click", (e) => {
        if (e.target === loginModal) loginModal.classList.remove("open");
      });
    }

    SM.auth.init();
  }

  // ── OTA UI ───────────────────────────────────────────────────────────────
  function setupOtaUI() {
    const dropZone = $("otaDropZone");
    const fileInput = $("otaFileInput");
    const fileNameEl = $("otaFileName");
    const uploadBtn = $("otaUploadBtn");
    const progressWrap = $("otaProgressWrap");
    const progressBar = $("otaProgressBar");
    const otaStatus = $("otaStatus");
    const targetMajorInput = $("targetFwMajor");
    const targetMinorInput = $("targetFwMinor");

    let selectedFile = null;

    function setStatus(msg, cls = "") {
      if (!otaStatus) return;
      otaStatus.textContent = msg;
      otaStatus.className = "ota-status " + cls;
    }

    // تحديث الإصدار المستهدف لما يكتب في الحقول
    function readTarget() {
      const maj = targetMajorInput ? parseInt(targetMajorInput.value, 10) : NaN;
      const min = targetMinorInput ? parseInt(targetMinorInput.value, 10) : NaN;
      targetFwMajor = isNaN(maj) ? null : maj;
      targetFwMinor = isNaN(min) ? null : min;
      renderTable();
    }
    if (targetMajorInput) targetMajorInput.addEventListener("input", readTarget);
    if (targetMinorInput) targetMinorInput.addEventListener("input", readTarget);

    function handleFile(file) {
      if (!file) return;
      selectedFile = file;
      if (fileNameEl) fileNameEl.textContent = file.name;
      if (uploadBtn) uploadBtn.disabled = false;
      setStatus("ملف جاهز: " + file.name);
    }

    if (dropZone) {
      dropZone.addEventListener("click", () => fileInput && fileInput.click());
      dropZone.addEventListener("dragover", (e) => {
        e.preventDefault();
        dropZone.classList.add("drag-over");
      });
      dropZone.addEventListener("dragleave", () => dropZone.classList.remove("drag-over"));
      dropZone.addEventListener("drop", (e) => {
        e.preventDefault();
        dropZone.classList.remove("drag-over");
        handleFile(e.dataTransfer.files[0]);
      });
    }

    if (fileInput) {
      fileInput.addEventListener("change", () => handleFile(fileInput.files[0]));
    }

    if (uploadBtn) {
      uploadBtn.addEventListener("click", async () => {
        if (!selectedFile) return;
        uploadBtn.disabled = true;
        if (progressWrap) progressWrap.style.display = "block";
        if (progressBar) progressBar.style.width = "0%";
        setStatus("جاري الرفع...");

        try {
          await SM.ota.sendFirmware(selectedFile, (pct) => {
            if (progressBar) progressBar.style.width = pct + "%";
          });
          if (progressBar) progressBar.style.width = "100%";
          setStatus("✅ تم رفع الفيرموير بنجاح", "ok");
          appendLog("✅ OTA: فيرموير اترفع بنجاح — " + selectedFile.name, "info");
        } catch (err) {
          setStatus("❌ " + err.message, "err");
          appendLog("❌ OTA فشل: " + err.message, "error");
        } finally {
          uploadBtn.disabled = false;
        }
      });
    }
  }

  // ── Log console clear ────────────────────────────────────────────────────
  function setupLogUI() {
    const clearBtn = $("clearLogBtn");
    if (clearBtn) {
      clearBtn.addEventListener("click", () => {
        const box = $("logConsole");
        if (box) box.innerHTML = "";
      });
    }
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  function init() {
    setupSerialUI();
    setupAuthUI();
    setupOtaUI();
    setupLogUI();
    setInterval(renderTable, 1000); // فحص انقطاع النودز كل ثانية
    appendLog("IPS Mesh Monitor جاهز — اضغط 'اتصل بـRoot' لبدء الاستقبال", "info");
  }

  return { init };
})();

// بدء كل حاجة لما الصفحة تاخد وقتها
document.addEventListener("DOMContentLoaded", SM.dashboard.init);
