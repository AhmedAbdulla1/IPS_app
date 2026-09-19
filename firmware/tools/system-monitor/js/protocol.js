// بروتوكول الـ HEALTH message من الـRoot:
// Format: HEALTH:<nodeIdHex_32chars>:<status>:<hop>:<timestamp_ms>\n
// مثال: HEALTH:f6074228a4c6ab680aad277807c10b77:online:2:17175
//
// بنفكه هنا لـ object عشان dashboard.js و health_protocol تاني

window.SM = window.SM || {};

SM.protocol = {
  // فك بروتوكول HEALTH line أو JSON لـ structured object
  parse: function(line) {
    if (!line) return null;

    // 1. تجربة فك JSON
    if (line.trim().startsWith('{')) {
      try {
        const obj = JSON.parse(line.trim());
        if (obj.type === 'health' || obj.node_id || obj.node_id_hex) {
          return {
            nodeIdHex: (obj.node_id || obj.node_id_hex || '').replace(/[^a-fA-F0-9]/g, '').toLowerCase(),
            status: obj.status || 'online',
            hopCount: typeof obj.hop_count === 'number' ? obj.hop_count : parseInt(obj.hop_count || 0, 10),
            fwMajor: typeof obj.fw_major === 'number' ? obj.fw_major : (obj.fw_major !== undefined ? parseInt(obj.fw_major, 10) : null),
            fwMinor: typeof obj.fw_minor === 'number' ? obj.fw_minor : (obj.fw_minor !== undefined ? parseInt(obj.fw_minor, 10) : null),
            timestamp: obj.last_seen_ms || Date.now(),
            receivedAt: Date.now(),
          };
        }
      } catch (e) {
        // ليس JSON صالحاً، أكمل تجربة النص العادي
      }
    }

    // 2. تجربة فك النص العادي HEALTH:...
    if (line.startsWith('HEALTH:')) {
      const parts = line.substring(7).split(':');
      if (parts.length >= 4) {
        const nodeIdHex = parts[0].replace(/[^a-fA-F0-9]/g, '').toLowerCase();
        const status = parts[1];
        const hopCount = parseInt(parts[2], 10);
        const timestamp = parseInt(parts[3], 10);
        const fwMajor = parts[4] !== undefined ? parseInt(parts[4], 10) : null;
        const fwMinor = parts[5] !== undefined ? parseInt(parts[5], 10) : null;

        return {
          nodeIdHex,
          status,
          hopCount,
          fwMajor,
          fwMinor,
          timestamp,
          receivedAt: Date.now(),
        };
      }
    }

    return null;
  },

  // صيغة HEALTH line
  format: function(nodeIdHex, status, hopCount, timestamp) {
    return `HEALTH:${nodeIdHex}:${status}:${hopCount}:${timestamp}`;
  },
};
