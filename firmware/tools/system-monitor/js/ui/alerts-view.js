// js/ui/alerts-view.js — High Performance Live Alerts Stream with Smart Deduplication

window.SM = window.SM || {};
SM.ui = SM.ui || {};

SM.ui.alertsView = (function () {
  const $ = (id) => document.getElementById(id);
  const MAX_ALERTS = 80;

  let container = null;
  let currentFilter = 'ALL'; // 'ALL' | 'CRITICAL' | 'WARNING'
  const recentAlerts = new Map(); // dedupKey -> timestamp

  function init() {
    container = $('alertsList');
  }

  function formatTime(d = new Date()) {
    return d.toLocaleTimeString('en-GB', { hour12: false });
  }

  function getSeverityIcon(type) {
    if (type === 'critical') return '🔴';
    if (type === 'warning')  return '⚠️';
    if (type === 'success')  return '🟢';
    return 'ℹ️';
  }

  function addAlert(type, title, detail, nodeUuid = null) {
    // 1. Always archive to local database
    if (SM.localDb && typeof SM.localDb.logEvent === 'function') {
      SM.localDb.logEvent(type, title, detail, nodeUuid);
    }

    if (!container) return;

    // 2. Deduplication check: drop duplicate alert within 60 seconds
    const dedupKey = `${type}:${title}:${detail}`;
    const now = Date.now();
    if (recentAlerts.has(dedupKey) && (now - recentAlerts.get(dedupKey) < 60000)) {
      return;
    }
    recentAlerts.set(dedupKey, now);

    if (recentAlerts.size > 200) {
      const oldestKey = recentAlerts.keys().next().value;
      recentAlerts.delete(oldestKey);
    }

    const timeStr = formatTime();
    const item = document.createElement('div');
    item.className = `alert-item ${type}`;
    item.setAttribute('data-severity', type);
    if (nodeUuid) item.setAttribute('data-node-uuid', nodeUuid);

    const isVisible = currentFilter === 'ALL' ||
      (currentFilter === 'CRITICAL' && type === 'critical') ||
      (currentFilter === 'WARNING' && (type === 'warning' || type === 'critical'));

    item.style.display = isVisible ? 'flex' : 'none';

    item.innerHTML = `
      <span class="alert-icon">${getSeverityIcon(type)}</span>
      <div class="alert-body">
        <div class="alert-title-row">
          <span class="alert-title">${title}</span>
          <span class="alert-time">${timeStr}</span>
        </div>
        <div class="alert-detail">${detail}</div>
      </div>
    `;

    // Prepend to top of stream smoothly
    container.insertBefore(item, container.firstChild);

    // Limit stream length to prevent memory leaks
    if (container.children.length > MAX_ALERTS) {
      container.removeChild(container.lastChild);
    }
  }

  function setFilter(filter) {
    currentFilter = filter;
    if (!container) return;

    Array.from(container.children).forEach(el => {
      const sev = el.getAttribute('data-severity');
      let vis = true;
      if (filter === 'CRITICAL' && sev !== 'critical') vis = false;
      if (filter === 'WARNING' && sev !== 'warning' && sev !== 'critical') vis = false;
      el.style.display = vis ? 'flex' : 'none';
    });
  }

  return {
    init,
    addAlert,
    setFilter,
  };
})();
