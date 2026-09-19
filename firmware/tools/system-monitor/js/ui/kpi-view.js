// js/ui/kpi-view.js — High Performance KPI Metrics View

window.SM = window.SM || {};
SM.ui = SM.ui || {};

SM.ui.kpiView = (function () {
  const $ = (id) => document.getElementById(id);

  function setText(id, text) {
    const el = $(id);
    if (el && el.textContent !== String(text)) {
      el.textContent = String(text);
    }
  }

  function update(nodesMap, effectiveTarget) {
    const nodes = Array.from(nodesMap.values());
    const total = nodes.length;

    let online = 0;
    let offline = 0;
    let warnings = 0;
    let maxHop = 0;
    let updated = 0;

    for (const n of nodes) {
      if (n.status === 'online') online++;
      else if (n.status === 'warning') { online++; warnings++; }
      else if (n.status === 'offline') offline++;

      if (n.hopCount && n.hopCount > maxHop) maxHop = n.hopCount;

      // Check if node firmware matches target
      if (effectiveTarget && effectiveTarget.major !== null) {
        const isMatch = n.fwMajor === effectiveTarget.major && 
          (n.fwMinor === null || effectiveTarget.minor === null || n.fwMinor >= effectiveTarget.minor);
        if (isMatch) updated++;
      } else if (n.fwMajor !== null && n.fwMajor !== undefined) {
        updated++;
      }
    }

    setText('kpiTotalNodes', total);
    setText('kpiOnlineNodes', online);
    setText('kpiOfflineNodes', offline);
    setText('kpiWarningNodes', warnings);
    setText('kpiMaxHop', maxHop > 0 ? `Hop ${maxHop}` : '—');

    const updatePct = total > 0 ? Math.round((updated / total) * 100) : 0;
    setText('kpiFwStatus', `${updated} / ${total} (${updatePct}%)`);

    const targetVerEl = $('kpiTargetVerText');
    if (targetVerEl) {
      let targetLabel = 'Target: Auto-detecting...';
      if (effectiveTarget && effectiveTarget.major !== null) {
        targetLabel = `Target: v${effectiveTarget.major}.${effectiveTarget.minor !== null ? effectiveTarget.minor : 0} (${effectiveTarget.label || 'Auto'})`;
      }
      if (targetVerEl.textContent !== targetLabel) {
        targetVerEl.textContent = targetLabel;
      }
    }

    const healthBar = $('networkHealthBar');
    if (healthBar) {
      const pct = total > 0 ? Math.round((online / total) * 100) : 0;
      const pctStr = `${pct}%`;
      if (healthBar.style.width !== pctStr) {
        healthBar.style.width = pctStr;
      }
    }
  }

  return {
    update,
  };
})();
