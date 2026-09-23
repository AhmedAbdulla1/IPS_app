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

  function filterOutdatedInTable() {
    if (SM.ui && SM.ui.tableView && typeof SM.ui.tableView.setFilter === 'function') {
      SM.ui.tableView.setFilter('OUTDATED');
      document.querySelectorAll('.table-filter-btn').forEach(b => {
        b.classList.toggle('active', b.getAttribute('data-filter') === 'OUTDATED');
      });
      const tableSec = document.querySelector('.table-panel');
      if (tableSec) tableSec.scrollIntoView({ behavior: 'smooth' });
    }
  }

  function init() {
    const headerFwBadge = $('headerFwWarningBadge');
    if (headerFwBadge) {
      headerFwBadge.addEventListener('click', filterOutdatedInTable);
    }

    const warningCard = $('kpiWarningCard');
    if (warningCard) {
      warningCard.addEventListener('click', filterOutdatedInTable);
    }
  }

  function update(nodesMap, effectiveTarget) {
    const allNodes = Array.from(nodesMap.values());
    // حساب أجهزة الهاردوير الحقيقية فقط لمؤشرات صحة الشبكة والفيرموير
    const physicalNodes = allNodes.filter(n => !n.isVirtual && n.hasRealUuid);
    const total = physicalNodes.length;

    let online = 0;
    let offline = 0;
    let linkWarnings = 0;
    let maxHop = 0;
    let updated = 0;
    let outdated = 0;

    for (const n of physicalNodes) {
      if (n.status === 'online') online++;
      else if (n.status === 'warning') { online++; linkWarnings++; }
      else if (n.status === 'offline') offline++;

      if (n.hopCount && n.hopCount > maxHop) maxHop = n.hopCount;

      // Check if node firmware matches target
      if (effectiveTarget && effectiveTarget.major !== null) {
        const isMatch = n.fwMajor === effectiveTarget.major && 
          (n.fwMinor === null || effectiveTarget.minor === null || n.fwMinor >= effectiveTarget.minor);
        if (isMatch) {
          updated++;
        } else {
          outdated++;
        }
      } else if (n.fwMajor !== null && n.fwMajor !== undefined) {
        updated++;
      }
    }

    const totalWarnings = linkWarnings + outdated;

    setText('kpiTotalNodes', total);
    setText('kpiOnlineNodes', online);
    setText('kpiOfflineNodes', offline);
    setText('kpiWarningNodes', totalWarnings);

    // Detailed Warning Subtext (including outdated nodes count)
    const warningSubEl = $('kpiWarningSub');
    if (warningSubEl) {
      if (outdated > 0) {
        warningSubEl.innerHTML = `⚠️ <strong style="color: var(--status-warning, #F5A623);">${outdated} outdated FW</strong>${linkWarnings > 0 ? ` + ${linkWarnings} link alert` : ''}`;
      } else if (linkWarnings > 0) {
        warningSubEl.textContent = `${linkWarnings} high hop alert(s)`;
      } else {
        warningSubEl.textContent = 'All nodes up to date & stable';
      }
    }

    setText('kpiMaxHop', maxHop > 0 ? `Hop ${maxHop}` : '—');

    const updatePct = total > 0 ? Math.round((updated / total) * 100) : 0;
    setText('kpiFwStatus', `${updated} / ${total} (${updatePct}%)`);

    // Top Operations Navbar Outdated Warning Pill Badge
    const headerFwBadge = $('headerFwWarningBadge');
    const headerOutdatedCount = $('headerOutdatedCount');
    if (headerFwBadge) {
      if (outdated > 0) {
        headerFwBadge.style.display = 'inline-flex';
        if (headerOutdatedCount) headerOutdatedCount.textContent = outdated;
      } else {
        headerFwBadge.style.display = 'none';
      }
    }

    const targetVerEl = $('kpiTargetVerText');
    if (targetVerEl) {
      if (outdated > 0) {
        targetVerEl.innerHTML = `<span style="color: var(--status-warning, #F5A623); font-weight: 600;">⚠️ ${outdated} node(s) need update</span> (Target v${effectiveTarget.major}.${effectiveTarget.minor || 0})`;
      } else if (total > 0 && updated === total) {
        targetVerEl.innerHTML = `<span style="color: var(--status-online, #3DDC84); font-weight: 600;">✅ All nodes v${effectiveTarget.major}.${effectiveTarget.minor || 0}</span>`;
      } else if (effectiveTarget && effectiveTarget.major !== null) {
        targetVerEl.textContent = `Target: v${effectiveTarget.major}.${effectiveTarget.minor !== null ? effectiveTarget.minor : 0} (${effectiveTarget.label || 'Auto'})`;
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
    init,
    update,
    filterOutdatedInTable,
  };
})();
