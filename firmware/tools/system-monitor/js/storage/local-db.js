// js/storage/local-db.js — TRANEX Local Database & Structured Telemetry History Storage
// Combines In-Browser IndexedDB for fast local queries and local filesystem persistence via /api/telemetry

window.SM = window.SM || {};

SM.localDb = (function () {
  const DB_NAME = 'TRANEX_IPS_LOCAL_DB';
  const DB_VERSION = 1;
  let db = null;
  let pendingBuffer = [];
  let flushTimer = null;

  // ── 1. Initialize IndexedDB ──────────────────────────────────────────────
  async function init() {
    return new Promise((resolve) => {
      if (!window.indexedDB) {
        console.warn('[local-db] IndexedDB is not supported in this environment');
        resolve(null);
        return;
      }

      const request = window.indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = (e) => {
        const dbInstance = e.target.result;
        
        // Store 1: Raw Telemetry Packets & Heartbeats
        if (!dbInstance.objectStoreNames.contains('telemetry_history')) {
          const telemStore = dbInstance.createObjectStore('telemetry_history', { keyPath: 'id', autoIncrement: true });
          telemStore.createIndex('timestamp', 'timestamp', { unique: false });
          telemStore.createIndex('nodeId', 'nodeId', { unique: false });
          telemStore.createIndex('status', 'status', { unique: false });
          telemStore.createIndex('date', 'date', { unique: false });
        }

        // Store 2: System & Network Events
        if (!dbInstance.objectStoreNames.contains('system_events')) {
          const eventStore = dbInstance.createObjectStore('system_events', { keyPath: 'id', autoIncrement: true });
          eventStore.createIndex('timestamp', 'timestamp', { unique: false });
          eventStore.createIndex('type', 'type', { unique: false });
          eventStore.createIndex('nodeUuid', 'nodeUuid', { unique: false });
        }
      };

      request.onsuccess = (e) => {
        db = e.target.result;
        console.log('[local-db] ✅ IndexedDB initialized successfully');
        resolve(db);
      };

      request.onerror = (e) => {
        console.error('[local-db] IndexedDB open error:', e.target.error);
        resolve(null);
      };
    });
  }

  // ── 2. Log Telemetry Entry ───────────────────────────────────────────────
  function logTelemetry(nodeData) {
    if (!nodeData) return;

    const dateStr = new Date().toISOString().slice(0, 10);
    const entry = {
      timestamp: Date.now(),
      date: dateStr,
      time: new Date().toLocaleTimeString('en-GB'),
      nodeId: nodeData.uuid || nodeData.cleanUuid || nodeData.nodeIdHex,
      nodeUuid: nodeData.uuid || nodeData.cleanUuid || nodeData.nodeIdHex,
      nodeName: nodeData.nameEn || nodeData.nameAr || 'Node',
      floor: nodeData.levelId || '—',
      status: nodeData.status || 'online',
      hop: nodeData.hopCount !== undefined ? nodeData.hopCount : 1,
      hopCount: nodeData.hopCount !== undefined ? nodeData.hopCount : 1,
      parent: nodeData.parent || 'Root Gateway',
      fwMajor: nodeData.fwMajor,
      fwMinor: nodeData.fwMinor,
    };

    // 1. Save to IndexedDB asynchronously
    if (db) {
      try {
        const tx = db.transaction(['telemetry_history'], 'readwrite');
        const store = tx.objectStore('telemetry_history');
        store.add(entry);
      } catch (err) {
        console.warn('[local-db] IndexedDB write warning:', err);
      }
    }

    // 2. Buffer for batch disk storage via /api/telemetry
    pendingBuffer.push(entry);
    scheduleFlush();
  }

  // ── 3. Log System Event ──────────────────────────────────────────────────
  function logEvent(type, title, detail, nodeUuid = null) {
    const entry = {
      timestamp: Date.now(),
      date: new Date().toISOString().slice(0, 10),
      time: new Date().toLocaleTimeString('en-GB'),
      type,
      title,
      detail,
      nodeUuid,
    };

    if (db) {
      try {
        const tx = db.transaction(['system_events'], 'readwrite');
        const store = tx.objectStore('system_events');
        store.add(entry);
      } catch (err) {}
    }
  }

  // ── 4. Flush to Local File via Server ────────────────────────────────────
  function scheduleFlush() {
    if (flushTimer) return;
    flushTimer = setTimeout(async () => {
      flushTimer = null;
      if (pendingBuffer.length === 0) return;

      const batch = [...pendingBuffer];
      pendingBuffer = [];

      try {
        await fetch('/api/telemetry', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(batch),
        });
      } catch (err) {
        // Fallback: restore unwritten batch
        pendingBuffer.unshift(...batch);
      }
    }, 2000);
  }

  // ── 5. Query Historical Telemetry ────────────────────────────────────────
  async function queryHistory({ nodeId = null, nodeUuid = null, limit = 100 } = {}) {
    const targetNode = nodeUuid || nodeId;
    const filterParam = (targetNode && targetNode !== 'ALL') ? targetNode : null;

    // 1. Try local server endpoint first
    try {
      const url = `/api/history?limit=${limit}${filterParam ? `&node=${encodeURIComponent(filterParam)}` : ''}`;
      const res = await fetch(url);
      if (res.ok) {
        const data = await res.json();
        return data.records || [];
      }
    } catch (e) {}

    // 2. Fallback to IndexedDB
    if (!db) return [];

    return new Promise((resolve) => {
      try {
        const tx = db.transaction(['telemetry_history'], 'readonly');
        const store = tx.objectStore('telemetry_history');
        const results = [];

        const request = store.openCursor(null, 'prev');
        request.onsuccess = (e) => {
          const cursor = e.target.result;
          if (cursor && results.length < limit) {
            const item = cursor.value;
            const itemNode = item.nodeUuid || item.nodeId;
            if (!filterParam || itemNode === filterParam) {
              results.push(item);
            }
            cursor.continue();
          } else {
            resolve(results);
          }
        };
        request.onerror = () => resolve([]);
      } catch (err) {
        resolve([]);
      }
    });
  }

  // ── 6. Export History as CSV / JSON ──────────────────────────────────────
  async function exportHistoryCsv(nodeId = null) {
    const records = await queryHistory({ nodeId, limit: 1000 });
    if (records.length === 0) {
      alert('No history records found to export.');
      return;
    }

    const headers = ['Timestamp', 'Time', 'Node ID', 'Node Name', 'Status', 'Hop Count', 'Parent', 'Firmware'];
    const rows = records.map(r => [
      r.timestamp,
      `"${r.time || ''}"`,
      `"${r.nodeId || ''}"`,
      `"${r.name || ''}"`,
      r.status || '',
      r.hopCount || '',
      `"${r.parent || ''}"`,
      `"v${r.fwMajor || 0}.${r.fwMinor || 0}"`,
    ]);

    const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tranex_mesh_history_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return {
    init,
    logTelemetry,
    logEvent,
    queryHistory,
    exportHistoryCsv,
  };
})();
