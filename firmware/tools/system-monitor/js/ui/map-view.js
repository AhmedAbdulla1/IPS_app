// js/ui/map-view.js — High Performance 60FPS Reactive SVG Map View
// 1:100 Architectural scale with persistent static layers & targeted element patching

window.SM = window.SM || {};
SM.ui = SM.ui || {};

SM.ui.mapView = (function () {
  const $ = (id) => document.getElementById(id);

  const SCALE = 10;        // 1m in reality = 10px in SVG
  const PAD = 45;          // Margin for axis numbers
  const GRID_SIZE = 110;   // 0m to 110m grid
  const TOTAL_W = GRID_SIZE * SCALE + PAD * 2; // 1190px
  const TOTAL_H = GRID_SIZE * SCALE + PAD * 2; // 1190px

  const rootGW_X = PAD + 53 * SCALE;
  const rootGW_Y = PAD + 53 * SCALE;

  let state = {
    zoom: 1,
    panX: 0,
    panY: 0,
    isPanning: false,
    startX: 0,
    startY: 0,
    selectedFloor: 'ALL',
    selectedUuid: null,
    onNodeSelect: null,
  };

  let svgRoot = null;
  let staticLayer = null;
  let linksLayer = null;
  let nodesLayer = null;

  function init(options = {}) {
    state.onNodeSelect = options.onNodeSelect || null;
    svgRoot = $('topologySvg');
    if (!svgRoot) return;

    setupSvgLayers();
    renderStaticBackground();
    setupPanZoomEvents();
    updateViewBox();
  }

  function setupSvgLayers() {
    svgRoot.innerHTML = `
      <defs>
        <!-- Minor 1m Grid Pattern -->
        <pattern id="grid1m" width="${SCALE}" height="${SCALE}" patternUnits="userSpaceOnUse">
          <path d="M ${SCALE} 0 L 0 0 0 ${SCALE}" fill="none" stroke="rgba(255,255,255,0.035)" stroke-width="0.5"/>
        </pattern>
        <!-- Glow Filters -->
        <filter id="glow-green" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="3.5" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over"/>
        </filter>
        <filter id="glow-orange" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="3.5" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over"/>
        </filter>
      </defs>
      <g id="svgStaticLayer"></g>
      <g id="svgLinksLayer"></g>
      <g id="svgNodesLayer"></g>
    `;

    staticLayer = $('svgStaticLayer');
    linksLayer = $('svgLinksLayer');
    nodesLayer = $('svgNodesLayer');
  }

  function renderStaticBackground() {
    if (!staticLayer) return;

    let content = `
      <!-- Deep Architectural Canvas -->
      <rect x="-800" y="-800" width="${TOTAL_W + 1600}" height="${TOTAL_H + 1600}" fill="#0A0A0A" />
      <rect x="${PAD}" y="${PAD}" width="${GRID_SIZE * SCALE}" height="${GRID_SIZE * SCALE}" fill="url(#grid1m)" />
    `;

    // Red Vertical Lines every 10m (Screen Horizontal Axis = DB Y)
    for (let x = 0; x <= GRID_SIZE; x += 10) {
      const lineX = PAD + x * SCALE;
      content += `
        <line x1="${lineX}" y1="${PAD}" x2="${lineX}" y2="${PAD + GRID_SIZE * SCALE}" 
              stroke="rgba(239, 68, 68, 0.4)" stroke-width="1.2" />
        <text x="${lineX}" y="${PAD - 10}" text-anchor="middle" fill="#FFA040" font-size="11" font-family="monospace" font-weight="bold">${x}</text>
      `;
    }

    // Amber Horizontal Lines every 10m (Screen Vertical Axis = DB X)
    for (let y = 0; y <= GRID_SIZE; y += 10) {
      const lineY = PAD + y * SCALE;
      content += `
        <line x1="${PAD}" y1="${lineY}" x2="${PAD + GRID_SIZE * SCALE}" y2="${lineY}" 
              stroke="rgba(243, 111, 33, 0.35)" stroke-width="1.2" />
        <text x="${PAD - 10}" y="${lineY + 4}" text-anchor="end" fill="#FFA040" font-size="11" font-family="monospace" font-weight="bold">${y}</text>
      `;
    }

    // Outer Map Perimeter
    content += `
      <rect x="${PAD}" y="${PAD}" width="${GRID_SIZE * SCALE}" height="${GRID_SIZE * SCALE}" 
            fill="none" stroke="rgba(243, 111, 33, 0.55)" stroke-width="1.5" />
    `;

    // Physical Building Edges/Corridors from Supabase
    const edges = SM.nodesRepo ? SM.nodesRepo.getEdges() : [];
    if (edges && edges.length > 0) {
      for (const edge of edges) {
        const nodeA = SM.nodesRepo.lookupById(edge.node_id_a);
        const nodeB = SM.nodesRepo.lookupById(edge.node_id_b);
        if (nodeA && nodeB && nodeA.x !== null && nodeA.y !== null && nodeB.x !== null && nodeB.y !== null) {
          if (state.selectedFloor !== 'ALL' && nodeA.level_id !== state.selectedFloor) continue;

          // Transposed coordinates: Horizontal = Y, Vertical = X
          const ax = PAD + nodeA.y * SCALE;
          const ay = PAD + nodeA.x * SCALE;
          const bx = PAD + nodeB.y * SCALE;
          const by = PAD + nodeB.x * SCALE;

          content += `
            <line x1="${ax}" y1="${ay}" x2="${bx}" y2="${by}" 
                  stroke="rgba(255, 255, 255, 0.16)" stroke-width="3" stroke-linecap="round" />
            <line x1="${ax}" y1="${ay}" x2="${bx}" y2="${by}" 
                  stroke="rgba(18, 18, 18, 0.8)" stroke-width="1.2" stroke-linecap="round" />
          `;
        }
      }
    }

    // Root Gateway Symbol
    content += `
      <g class="map-node-root" transform="translate(${rootGW_X}, ${rootGW_Y})">
        <circle r="14" fill="rgba(243, 111, 33, 0.15)" stroke="#F36F21" stroke-width="1.5" stroke-dasharray="3,3"/>
        <circle r="7" fill="#1A1A1A" stroke="#F36F21" stroke-width="1.5" />
        <text y="3" text-anchor="middle" fill="#F36F21" font-size="8" font-weight="bold">📡</text>
        <text y="22" text-anchor="middle" fill="#FFA040" font-size="9" font-family="'Inter', sans-serif" font-weight="700">Root Gateway</text>
      </g>
    `;

    staticLayer.innerHTML = content;
  }

  function getNodeCoordinates(node, unmappedIndex = 0) {
    if (node.x !== null && node.y !== null && !isNaN(node.x) && !isNaN(node.y)) {
      // Horizontal = Y, Vertical = X
      return {
        x: PAD + node.y * SCALE,
        y: PAD + node.x * SCALE,
        isUnmapped: false,
      };
    }
    // Unmapped nodes placed in structured sidebar within canvas
    return {
      x: PAD + 980,
      y: PAD + 800 + unmappedIndex * 35,
      isUnmapped: true,
    };
  }

  function getStatusColor(status) {
    if (status === 'online') return '#3DDC84'; // Emerald Green
    if (status === 'warning') return '#F5A623'; // Amber
    if (status === 'offline') return '#C97B6E'; // Coral Red
    return '#6E6E6E'; // Neutral Gray
  }

  // ── Fine-Grained Node Patching ──────────────────────────────────────────
  function patchNode(node, unmappedIdx = 0) {
    if (!nodesLayer) return;

    // Check floor filter
    const isVisible = state.selectedFloor === 'ALL' || node.levelId === state.selectedFloor;
    const existingGroup = document.getElementById(`map-node-${node.uuid}`);

    if (!isVisible) {
      if (existingGroup) existingGroup.style.display = 'none';
      removeMeshLink(node.uuid);
      return;
    }

    const coords = getNodeCoordinates(node, unmappedIdx);
    const color = getStatusColor(node.status);
    const isSelected = state.selectedUuid === node.uuid;
    const isOnline = node.status === 'online' || node.status === 'warning';

    if (!existingGroup) {
      // Create new SVG node group once
      const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
      g.setAttribute('id', `map-node-${node.uuid}`);
      g.setAttribute('class', `map-node-item ${isSelected ? 'selected' : ''}`);
      g.setAttribute('transform', `translate(${coords.x}, ${coords.y})`);
      g.style.cursor = 'pointer';

      g.innerHTML = `
        <circle class="pulse-ring" r="12" fill="none" stroke="${color}" stroke-width="1.2" opacity="0.6" style="display: ${node.status === 'online' ? 'block' : 'none'};">
          <animate attributeName="r" values="7;13;7" dur="3s" repeatCount="indefinite"/>
        </circle>
        <circle class="select-ring" r="10" fill="none" stroke="#F36F21" stroke-width="2" style="display: ${isSelected ? 'block' : 'none'};"/>
        <circle class="main-dot" r="6.5" fill="#161616" stroke="${color}" stroke-width="${isSelected ? 2.5 : 1.8}" />
        <circle class="center-dot" r="3" fill="${color}" />
        
        <!-- Label Pill -->
        <g class="label-group" transform="translate(0, -14)">
          <rect x="-38" y="-12" width="76" height="15" rx="3" 
                fill="rgba(20, 20, 20, 0.9)" stroke="rgba(255,255,255,0.15)" stroke-width="0.75" />
          <text class="node-label-text" x="0" y="-2" text-anchor="middle" fill="${isSelected ? '#F36F21' : '#FFFFFF'}" 
                font-size="8.5" font-weight="600" font-family="'Inter', sans-serif">${node.nameEn || node.nameAr}</text>
        </g>
        <text class="hop-text" y="15" text-anchor="middle" fill="#9E9E9E" font-size="7.5" font-family="monospace">
          ${node.hopCount ? `Hop ${node.hopCount}` : (node.isFromDb ? 'Registered' : '')}
        </text>
      `;

      g.addEventListener('click', (e) => {
        e.stopPropagation();
        const targetUuid = (state.selectedUuid === node.uuid) ? null : node.uuid;
        selectNode(targetUuid);
        if (typeof state.onNodeSelect === 'function') {
          state.onNodeSelect(targetUuid);
        }
      });

      nodesLayer.appendChild(g);
    } else {
      // Patch only modified attributes without recreating DOM elements
      existingGroup.style.display = 'block';
      existingGroup.classList.toggle('selected', isSelected);

      const mainDot = existingGroup.querySelector('.main-dot');
      if (mainDot) {
        mainDot.setAttribute('stroke', color);
        mainDot.setAttribute('stroke-width', isSelected ? '2.5' : '1.8');
      }

      const centerDot = existingGroup.querySelector('.center-dot');
      if (centerDot) centerDot.setAttribute('fill', color);

      const pulseRing = existingGroup.querySelector('.pulse-ring');
      if (pulseRing) {
        pulseRing.setAttribute('stroke', color);
        pulseRing.style.display = node.status === 'online' ? 'block' : 'none';
      }

      const selectRing = existingGroup.querySelector('.select-ring');
      if (selectRing) {
        selectRing.style.display = isSelected ? 'block' : 'none';
      }

      const labelText = existingGroup.querySelector('.node-label-text');
      if (labelText) {
        labelText.setAttribute('fill', isSelected ? '#F36F21' : '#FFFFFF');
        labelText.textContent = node.nameEn || node.nameAr;
      }

      const hopText = existingGroup.querySelector('.hop-text');
      if (hopText) {
        hopText.textContent = node.hopCount ? `Hop ${node.hopCount}` : (node.isFromDb ? 'Registered' : '');
      }
    }

    // Patch Mesh Link for this node
    patchMeshLink(node, coords, isOnline);
  }

  // ── Fine-Grained Mesh Link Patching ────────────────────────────────────
  function patchMeshLink(node, coords, isOnline) {
    if (!linksLayer) return;

    const linkId = `mesh-link-${node.uuid}`;
    let linkEl = document.getElementById(linkId);

    if (!isOnline || !node.hopCount) {
      if (linkEl) linkEl.remove();
      return;
    }

    let tx = rootGW_X;
    let ty = rootGW_Y;

    // Hop 3 connects to nearest online Hop 2 node if present
    if (node.hopCount === 3 && SM.nodes) {
      let minDist = Infinity;
      for (const other of SM.nodes.values()) {
        if (other.hopCount === 2 && (other.status === 'online' || other.status === 'warning') && other.uuid !== node.uuid) {
          const oc = getNodeCoordinates(other);
          const d = Math.hypot(oc.x - coords.x, oc.y - coords.y);
          if (d < minDist) {
            minDist = d;
            tx = oc.x;
            ty = oc.y;
          }
        }
      }
    }

    const isSelected = state.selectedUuid === node.uuid;
    const strokeColor = isSelected ? '#F36F21' : (node.hopCount >= 3 ? '#F5A623' : '#3DDC84');

    if (!linkEl) {
      linkEl = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      linkEl.setAttribute('id', linkId);
      linkEl.setAttribute('stroke-dasharray', '4,4');
      linkEl.setAttribute('opacity', '0.75');
      linksLayer.appendChild(linkEl);
    }

    linkEl.setAttribute('x1', tx);
    linkEl.setAttribute('y1', ty);
    linkEl.setAttribute('x2', coords.x);
    linkEl.setAttribute('y2', coords.y);
    linkEl.setAttribute('stroke', strokeColor);
    linkEl.setAttribute('stroke-width', isSelected ? '2.5' : '1.5');
  }

  function removeMeshLink(uuid) {
    const linkEl = document.getElementById(`mesh-link-${uuid}`);
    if (linkEl) linkEl.remove();
  }

  function selectNode(uuid) {
    state.selectedUuid = uuid;
    if (!nodesLayer) return;

    // Update selection rings on all nodes
    nodesLayer.querySelectorAll('.map-node-item').forEach(el => {
      const elUuid = el.id.replace('map-node-', '');
      const isSel = elUuid === uuid;
      el.classList.toggle('selected', isSel);

      const selRing = el.querySelector('.select-ring');
      if (selRing) selRing.style.display = isSel ? 'block' : 'none';

      const labelText = el.querySelector('.node-label-text');
      if (labelText) labelText.setAttribute('fill', isSel ? '#F36F21' : '#FFFFFF');
    });

    // Update active link stroke
    if (linksLayer) {
      linksLayer.querySelectorAll('line').forEach(l => {
        const isSel = l.id === `mesh-link-${uuid}`;
        l.setAttribute('stroke-width', isSel ? '2.5' : '1.5');
        if (isSel) l.setAttribute('stroke', '#F36F21');
      });
    }
  }

  function setFloor(floorId) {
    state.selectedFloor = floorId;
    renderStaticBackground();
  }

  // ── Pan and Zoom Handlers ──────────────────────────────────────────────
  function updateViewBox() {
    if (!svgRoot) return;
    const z = state.zoom;
    const vbW = TOTAL_W / z;
    const vbH = TOTAL_H / z;
    const vbX = (TOTAL_W - vbW) / 2 - state.panX;
    const vbY = (TOTAL_H - vbH) / 2 - state.panY;
    svgRoot.setAttribute('viewBox', `${vbX} ${vbY} ${vbW} ${vbH}`);
  }

  function setupPanZoomEvents() {
    const container = svgRoot.parentElement;
    if (!container) return;

    container.addEventListener('mousedown', (e) => {
      if (e.button !== 0) return;
      state.isPanning = true;
      state.startX = e.clientX;
      state.startY = e.clientY;
      state.startPanX = state.panX;
      state.startPanY = state.panY;
    });

    window.addEventListener('mousemove', (e) => {
      if (!state.isPanning) return;
      const dx = (e.clientX - state.startX) / state.zoom;
      const dy = (e.clientY - state.startY) / state.zoom;
      state.panX = state.startPanX + dx;
      state.panY = state.startPanY + dy;
      updateViewBox();
    });

    window.addEventListener('mouseup', () => {
      state.isPanning = false;
    });

    container.addEventListener('wheel', (e) => {
      e.preventDefault();
      const delta = e.deltaY < 0 ? 1.15 : 0.85;
      zoom(delta);
    }, { passive: false });
  }

  function zoom(factor) {
    state.zoom = Math.min(Math.max(state.zoom * factor, 0.4), 8);
    updateViewBox();
  }

  function zoomIn() { zoom(1.25); }
  function zoomOut() { zoom(0.8); }
  function resetZoom() {
    state.zoom = 1;
    state.panX = 0;
    state.panY = 0;
    updateViewBox();
  }

  return {
    init,
    patchNode,
    selectNode,
    setFloor,
    zoomIn,
    zoomOut,
    resetZoom,
  };
})();
