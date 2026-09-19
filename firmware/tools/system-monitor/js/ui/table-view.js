// js/ui/table-view.js — High Performance Keyed Table View
// Fine-grained cell updates without full table rewrites or scroll resetting

window.SM = window.SM || {};
SM.ui = SM.ui || {};

SM.ui.tableView = (function () {
  const $ = (id) => document.getElementById(id);

  let state = {
    selectedUuid: null,
    filter: 'ALL',      // 'ALL' | 'ONLINE' | 'OFFLINE' | 'OUTDATED'
    floorFilter: 'ALL',
    searchQuery: '',
    onNodeSelect: null,
  };

  let tbody = null;

  function init(options = {}) {
    state.onNodeSelect = options.onNodeSelect || null;
    tbody = $('nodesTableBody');
  }

  function formatVersion(major, minor) {
    if (major === null || major === undefined) return '—';
    return `v${major}.${minor !== null && minor !== undefined ? minor : '0'}`;
  }

  function isFwUpToDate(n, target) {
    if (!target || target.major === null) return true;
    if (n.fwMajor === null || n.fwMajor === undefined) return false;
    return n.fwMajor === target.major && 
      (n.fwMinor === null || target.minor === null || n.fwMinor >= target.minor);
  }

  function getStatusBadgeHtml(status) {
    if (status === 'online') {
      return '<span class="badge badge-success"><span class="pulse-dot"></span> ONLINE</span>';
    } else if (status === 'warning') {
      return '<span class="badge badge-warning">HIGH HOP</span>';
    } else if (status === 'offline') {
      return '<span class="badge badge-danger">OFFLINE</span>';
    }
    return '<span class="badge badge-neutral">STANDBY</span>';
  }

  function matchesFilterAndSearch(node, effectiveTarget) {
    // 1. Floor Filter
    if (state.floorFilter !== 'ALL' && node.levelId !== state.floorFilter) {
      return false;
    }

    // 2. Status Filter
    if (state.filter === 'ONLINE') {
      if (node.status !== 'online' && node.status !== 'warning') return false;
    } else if (state.filter === 'OFFLINE') {
      if (node.status !== 'offline' && node.status !== 'unknown') return false;
    } else if (state.filter === 'OUTDATED') {
      if (isFwUpToDate(node, effectiveTarget)) return false;
    }

    // 3. Search Query
    if (state.searchQuery) {
      const q = state.searchQuery.toLowerCase();
      const matchName = (node.nameEn && node.nameEn.toLowerCase().includes(q)) ||
                        (node.nameAr && node.nameAr.toLowerCase().includes(q));
      const matchUuid = node.uuid && node.uuid.toLowerCase().includes(q);
      const matchId = node.nodeId && String(node.nodeId).includes(q);
      if (!matchName && !matchUuid && !matchId) return false;
    }

    return true;
  }

  // ── Targeted Row Creation / Patching ──────────────────────────────────
  function patchRow(node, effectiveTarget, levelsList = []) {
    if (!tbody) return;

    const rowId = `tbl-row-${node.uuid}`;
    let tr = document.getElementById(rowId);
    const isSelected = state.selectedUuid === node.uuid;
    const isVisible = matchesFilterAndSearch(node, effectiveTarget);

    const floorObj = levelsList.find(l => l.level_id === node.levelId);
    const floorName = floorObj ? (floorObj.name_en || floorObj.level_id) : (node.levelId || '—');

    const isUpdated = isFwUpToDate(node, effectiveTarget);
    const fwBadgeHtml = node.fwMajor !== null
      ? `<span class="badge ${isUpdated ? 'badge-success' : 'badge-warning'}">${formatVersion(node.fwMajor, node.fwMinor)}</span>`
      : '<span class="badge badge-neutral">Unknown</span>';

    const now = Date.now();
    const elapsedSec = node.lastSeenTime ? Math.max(0, Math.round((now - node.lastSeenTime) / 1000)) : null;
    const lastSeenText = elapsedSec !== null ? `${elapsedSec}s ago` : '—';

    const displayName = node.nameEn || node.nameAr || `Node ${node.nodeId || ''}`;
    const displayUuid = node.displayUuid || (node.uuid.length > 16 ? `${node.uuid.slice(0, 8)}...${node.uuid.slice(-4)}` : node.uuid);

    if (!tr) {
      tr = document.createElement('tr');
      tr.id = rowId;
      tr.className = `node-row ${isSelected ? 'row-selected' : ''}`;
      tr.setAttribute('data-uuid', node.uuid);
      tr.style.display = isVisible ? '' : 'none';

      tr.innerHTML = `
        <td class="cell-status">${getStatusBadgeHtml(node.status)}</td>
        <td class="cell-node">
          <div class="table-node-name">${displayName}</div>
          <div class="table-node-uuid mono">${displayUuid}</div>
        </td>
        <td class="cell-floor" style="text-align:center"><span class="badge badge-floor">${floorName}</span></td>
        <td class="cell-hop" style="text-align:center">${node.hopCount ? `<span class="hop-chip">Hop ${node.hopCount}</span>` : '—'}</td>
        <td class="cell-parent" style="text-align:center;color:var(--text-muted);font-size:12px">${node.parent || '—'}</td>
        <td class="cell-fw" style="text-align:center">${fwBadgeHtml}</td>
        <td class="cell-lastseen" style="text-align:center;color:var(--text-muted);font-family:var(--font-mono)">${lastSeenText}</td>
        <td class="cell-actions" style="text-align:center">
          <button class="btn btn-xs btn-outline details-btn" data-uuid="${node.uuid}">Inspect</button>
        </td>
      `;

      tr.addEventListener('click', (e) => {
        const targetUuid = (state.selectedUuid === node.uuid) ? null : node.uuid;
        selectRow(targetUuid);
        if (typeof state.onNodeSelect === 'function') {
          state.onNodeSelect(targetUuid);
        }
      });

      // Remove initial empty state placeholder if present
      const emptyRow = tbody.querySelector('.empty-state');
      if (emptyRow) emptyRow.closest('tr').remove();

      // If online, insert at top of table so active nodes are immediately visible
      if ((node.status === 'online' || node.status === 'warning') && tbody.firstChild) {
        tbody.insertBefore(tr, tbody.firstChild);
      } else {
        tbody.appendChild(tr);
      }
    } else {
      // Patch only modified cell elements
      tr.style.display = isVisible ? '' : 'none';
      tr.classList.toggle('row-selected', isSelected);

      const statusCell = tr.querySelector('.cell-status');
      if (statusCell) statusCell.innerHTML = getStatusBadgeHtml(node.status);

      const nameEl = tr.querySelector('.table-node-name');
      if (nameEl && nameEl.textContent !== displayName) nameEl.textContent = displayName;

      const uuidEl = tr.querySelector('.table-node-uuid');
      if (uuidEl && uuidEl.textContent !== displayUuid) uuidEl.textContent = displayUuid;

      const hopCell = tr.querySelector('.cell-hop');
      if (hopCell) hopCell.innerHTML = node.hopCount ? `<span class="hop-chip">Hop ${node.hopCount}</span>` : '—';

      const parentCell = tr.querySelector('.cell-parent');
      if (parentCell && parentCell.textContent !== (node.parent || '—')) {
        parentCell.textContent = node.parent || '—';
      }

      const fwCell = tr.querySelector('.cell-fw');
      if (fwCell) fwCell.innerHTML = fwBadgeHtml;

      const lastSeenCell = tr.querySelector('.cell-lastseen');
      if (lastSeenCell) lastSeenCell.textContent = lastSeenText;

      // Bring active nodes to the top if not already at the top
      if ((node.status === 'online' || node.status === 'warning') && tbody.firstChild !== tr) {
        tbody.insertBefore(tr, tbody.firstChild);
      }
    }
  }

  // ── Periodic Seconds Counter (Ultra Fast & Lightweight) ────────────────
  function updateElapsedTimes(nodesMap) {
    if (!tbody) return;
    const now = Date.now();

    for (const [uuid, node] of nodesMap.entries()) {
      if (node.status === 'online' || node.status === 'warning') {
        const row = document.getElementById(`tbl-row-${uuid}`);
        if (row && row.style.display !== 'none') {
          const lastSeenCell = row.querySelector('.cell-lastseen');
          if (lastSeenCell && node.lastSeenTime) {
            const sec = Math.max(0, Math.round((now - node.lastSeenTime) / 1000));
            lastSeenCell.textContent = `${sec}s ago`;
          }
        }
      }
    }
  }

  function selectRow(uuid) {
    state.selectedUuid = uuid;
    if (!tbody) return;

    tbody.querySelectorAll('tr').forEach(tr => {
      const isSel = uuid !== null && tr.getAttribute('data-uuid') === uuid;
      tr.classList.toggle('row-selected', isSel);
    });
  }

  function setFilter(newFilter, nodesMap, effectiveTarget, levelsList) {
    state.filter = newFilter;
    refreshVisibility(nodesMap, effectiveTarget, levelsList);
  }

  function setFloorFilter(floorId, nodesMap, effectiveTarget, levelsList) {
    state.floorFilter = floorId;
    refreshVisibility(nodesMap, effectiveTarget, levelsList);
  }

  function setSearch(query, nodesMap, effectiveTarget, levelsList) {
    state.searchQuery = query;
    refreshVisibility(nodesMap, effectiveTarget, levelsList);
  }

  function refreshVisibility(nodesMap, effectiveTarget, levelsList) {
    if (!tbody) return;
    let visibleCount = 0;

    for (const node of nodesMap.values()) {
      const tr = document.getElementById(`tbl-row-${node.uuid}`);
      if (tr) {
        const isVis = matchesFilterAndSearch(node, effectiveTarget);
        tr.style.display = isVis ? '' : 'none';
        if (isVis) visibleCount++;
      } else {
        patchRow(node, effectiveTarget, levelsList);
        visibleCount++;
      }
    }

    // Toggle empty state if no rows visible
    let emptyRow = document.getElementById('tbl-empty-state-row');
    if (visibleCount === 0) {
      if (!emptyRow) {
        emptyRow = document.createElement('tr');
        emptyRow.id = 'tbl-empty-state-row';
        emptyRow.innerHTML = `
          <td colspan="8" class="empty-state">
            No mesh nodes match the current filter or search criteria.
          </td>
        `;
        tbody.appendChild(emptyRow);
      }
      emptyRow.style.display = '';
    } else if (emptyRow) {
      emptyRow.style.display = 'none';
    }
  }

  return {
    init,
    patchRow,
    updateElapsedTimes,
    selectRow,
    setFilter,
    setFloorFilter,
    setSearch,
    refreshVisibility,
  };
})();
