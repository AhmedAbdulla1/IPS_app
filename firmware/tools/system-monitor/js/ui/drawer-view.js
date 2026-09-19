// js/ui/drawer-view.js — Node Details Drawer & Debug Terminal Drawer

window.SM = window.SM || {};
SM.ui = SM.ui || {};

SM.ui.drawerView = (function () {
  const $ = (id) => document.getElementById(id);
  const MAX_LOGS = 300;

  let isLogPaused = false;
  let onCloseCallback = null;

  function init(options = {}) {
    onCloseCallback = options.onClose || null;

    // Close Drawer Button
    const closeBtn = $('closeDrawerBtn');
    if (closeBtn) {
      closeBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        closeNode();
      });
    }

    // Toggle Serial Drawer Button
    const toggleLogBtn = $('toggleLogDrawerBtn');
    if (toggleLogBtn) {
      toggleLogBtn.addEventListener('click', () => {
        const drawer = $('serialLogDrawer');
        if (drawer) drawer.classList.toggle('open');
      });
    }

    // Close Serial Drawer Button
    const closeLogBtn = $('closeLogDrawerBtn');
    if (closeLogBtn) {
      closeLogBtn.addEventListener('click', () => {
        const drawer = $('serialLogDrawer');
        if (drawer) drawer.classList.remove('open');
      });
    }

    // Clear Log Button
    const clearLogBtn = $('clearLogBtn');
    if (clearLogBtn) {
      clearLogBtn.addEventListener('click', clearLogs);
    }

    // Pause Log Button
    const pauseLogBtn = $('pauseLogBtn');
    if (pauseLogBtn) {
      pauseLogBtn.addEventListener('click', () => {
        isLogPaused = !isLogPaused;
        pauseLogBtn.textContent = isLogPaused ? '▶ Resume' : '⏸ Pause';
      });
    }

    // Close on Escape Key
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        if (isOpen()) closeNode();
        const logDrawer = $('serialLogDrawer');
        if (logDrawer && logDrawer.classList.contains('open')) {
          logDrawer.classList.remove('open');
        }
      }
    });
  }

  function isOpen() {
    const drawer = $('nodeDrawer');
    return drawer ? drawer.classList.contains('open') : false;
  }

  function renderContent(node, levelsList = []) {
    const floorObj = levelsList.find(l => l.level_id === node.levelId);
    const floorName = floorObj ? (floorObj.name_en || floorObj.level_id) : (node.levelId || '—');

    const setText = (id, text) => {
      const el = $(id);
      if (el && el.textContent !== text) el.textContent = text || '—';
    };

    setText('drawerNodeName', node.nameEn || node.nameAr || 'Unknown Node');
    setText('drawerNodeUuid', node.displayUuid || node.uuid || '—');
    setText('drawerStatus', (node.status || 'unknown').toUpperCase());
    setText('drawerFloor', floorName);
    setText('drawerHop', node.hopCount ? `Hop ${node.hopCount}` : 'Direct');
    setText('drawerParent', node.parent || 'Root Gateway');
    setText('drawerFirmware', node.fwMajor !== null ? `v${node.fwMajor}.${node.fwMinor !== null ? node.fwMinor : 0}` : 'Unknown');

    const coords = (node.x !== null && node.y !== null) ? `X: ${node.x}m, Y: ${node.y}m` : 'Unmapped / Floating';
    setText('drawerCoords', coords);
  }

  // Explicitly opened by user clicking a node
  function openNode(node, levelsList = []) {
    const drawer = $('nodeDrawer');
    if (!drawer || !node) return;

    renderContent(node, levelsList);
    drawer.classList.add('open');
  }

  // Passively updates text for selected node without forcing open state
  function updateNode(node, levelsList = []) {
    if (!isOpen() || !node) return;
    renderContent(node, levelsList);
  }

  function closeNode() {
    const drawer = $('nodeDrawer');
    if (drawer) drawer.classList.remove('open');
    if (typeof onCloseCallback === 'function') {
      onCloseCallback();
    }
  }

  function appendLog(line, type = 'info') {
    if (isLogPaused) return;
    const logBox = $('logConsole');
    if (!logBox) return;

    const item = document.createElement('div');
    item.className = `log-line ${type}`;
    item.textContent = `[${new Date().toLocaleTimeString('en-GB')}] ${line}`;

    logBox.appendChild(item);

    if (logBox.children.length > MAX_LOGS) {
      logBox.removeChild(logBox.firstChild);
    }

    logBox.scrollTop = logBox.scrollHeight;
  }

  function clearLogs() {
    const logBox = $('logConsole');
    if (logBox) logBox.innerHTML = '';
  }

  return {
    init,
    isOpen,
    openNode,
    updateNode,
    closeNode,
    appendLog,
    clearLogs,
  };
})();
