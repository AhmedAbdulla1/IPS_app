// js/nodes-repo.js — مستودع البنية التحتية من Supabase
// يعتمد على المخطط الفعلي لمشروع IPS:
// - جدول nodes: node_id (int), level_id (string), name_ar, name_en, type, facility_type, esp32_uuid, x, y
// - جدول levels: level_id, name_ar, name_en, level_order

window.SM = window.SM || {};

SM.nodesRepo = (function () {
  let nodesCache = [];
  let nodesByUuid = new Map(); // esp32_uuid (lowercase) -> node
  let nodesById = new Map();   // node_id -> node
  let levelsCache = [];
  let levelsById = new Map();  // level_id -> level
  let edgesCache = [];
  let supabaseClient = null;
  let isInitialized = false;

  function getClient() {
    if (!supabaseClient && window.supabase && SM.config) {
      supabaseClient = window.supabase.createClient(
        SM.config.SUPABASE_URL,
        SM.config.SUPABASE_ANON_KEY
      );
    }
    return supabaseClient;
  }

  function normalizeUuid(uuid) {
    if (!uuid) return '';
    return String(uuid).replace(/[^a-fA-F0-9]/g, '').toLowerCase();
  }

  async function refresh() {
    const client = getClient();
    if (!client) {
      console.warn('[nodes-repo] لم يتم تهيئة Supabase client');
      return { nodes: [], levels: [] };
    }

    try {
      // 1. جلب الأدوار (Levels)
      const { data: levelsData, error: levelsErr } = await client
        .from('levels')
        .select('level_id, name_ar, name_en, level_order')
        .order('level_order', { ascending: true });

      if (levelsErr) {
        console.warn('[nodes-repo] تعذر جلب الأدوار (قد لا يكون الجدول موجوداً بعد):', levelsErr.message);
      } else if (levelsData) {
        levelsCache = levelsData;
        levelsById.clear();
        for (const lvl of levelsData) {
          levelsById.set(lvl.level_id, lvl);
        }
      }

      // 2. جلب جميع عقد البنية التحتية (Nodes)
      const { data: nodesData, error: nodesErr } = await client
        .from('nodes')
        .select('node_id, level_id, name_ar, name_en, type, facility_type, esp32_uuid, x, y');

      if (nodesErr) {
        console.error('[nodes-repo] خطأ أثناء جلب النودز من Supabase:', nodesErr);
        return { nodes: nodesCache, levels: levelsCache };
      }

      nodesCache = nodesData || [];
      nodesByUuid.clear();
      nodesById.clear();

      for (const node of nodesCache) {
        if (node.node_id !== undefined && node.node_id !== null) {
          nodesById.set(node.node_id, node);
        }
        if (node.esp32_uuid) {
          const cleanKey = normalizeUuid(node.esp32_uuid);
          node.normalized_uuid = cleanKey;
          nodesByUuid.set(cleanKey, node);
        }
      }

      // 3. جلب مسارات وممرات الطوابق (Edges)
      const { data: edgesData, error: edgesErr } = await client
        .from('edges')
        .select('edge_id, node_id_a, node_id_b, distance_meters, kind, connector_name');

      if (!edgesErr && edgesData) {
        edgesCache = edgesData;
      }

      isInitialized = true;
      console.log(`[nodes-repo] ✅ تم تحميل ${nodesCache.length} نود و ${levelsCache.length} دور و ${edgesCache.length} مسار من Supabase`);
      return { nodes: nodesCache, levels: levelsCache, edges: edgesCache };

    } catch (err) {
      console.error('[nodes-repo] استثناء أثناء جلب بيانات البنية التحتية:', err);
      return { nodes: nodesCache, levels: levelsCache };
    }
  }

  function lookupByUuid(uuid) {
    if (!uuid) return null;
    return nodesByUuid.get(normalizeUuid(uuid)) || null;
  }

  function lookupById(id) {
    return nodesById.get(id) || null;
  }

  function getAllNodes() {
    return [...nodesCache];
  }

  function getLevels() {
    return [...levelsCache];
  }

  function getLevel(levelId) {
    return levelsById.get(levelId) || null;
  }

  function isReady() {
    return isInitialized;
  }

  function getEdges() {
    return [...edgesCache];
  }

  return {
    getClient,
    refresh,
    lookupByUuid,
    lookupById,
    getAllNodes,
    getLevels,
    getLevel,
    getEdges,
    isReady,
    normalizeUuid,
  };
})();
