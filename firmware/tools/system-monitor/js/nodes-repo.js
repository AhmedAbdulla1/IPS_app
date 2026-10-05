// js/nodes-repo.js — مستودع البنية التحتية والمسارات المتكامل من Supabase
// يدعم القراءة، والربط الرسومي، وحفظ المسارات والتعديلات (Batch Staging & Sync)

window.SM = window.SM || {};

SM.nodesRepo = (function () {
  let nodesCache = [];
  let nodesByUuid = new Map(); // esp32_uuid (lowercase) -> node
  let nodesById = new Map();   // node_id -> node
  let levelsCache = [];
  let levelsById = new Map();  // level_id -> level
  let edgesCache = [];
  let originalEdgesSnapshot = []; // baseline for discarding changes
  let supabaseClient = null;
  let isInitialized = false;

  // ── Staging Variables (لإدارة التعديلات في المسودة قبل الرفع) ─────────────
  let stagedAddedEdges = [];      // Edges created locally (temp IDs)
  let stagedDeletedEdgeIds = new Set(); // Existing edge IDs marked for DB deletion
  let stagedUpdatedEdges = new Map();   // edgeId -> { distance_meters, kind, connector_name }

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

  function resetStaged() {
    stagedAddedEdges = [];
    stagedDeletedEdgeIds.clear();
    stagedUpdatedEdges.clear();
  }

  async function refresh() {
    const client = getClient();
    if (!client) {
      console.warn('[nodes-repo] لم يتم تهيئة Supabase client، محاولة استخدام النسخة المحلية...');
      return loadLocalFallback();
    }

    try {
      // 1. جلب الأدوار (Levels)
      const { data: levelsData, error: levelsErr } = await client
        .from('levels')
        .select('level_id, name_ar, name_en, level_order')
        .order('level_order', { ascending: true });

      if (levelsErr) {
        console.warn('[nodes-repo] تعذر جلب الأدوار:', levelsErr.message);
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
        if (nodesCache.length === 0) return loadLocalFallback();
        return { nodes: nodesCache, levels: levelsCache, edges: edgesCache };
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

      // حفظ نسخة مطابقة للأصل لإتاحة التراجع (Discard)
      originalEdgesSnapshot = JSON.parse(JSON.stringify(edgesCache));
      resetStaged();

      isInitialized = true;
      console.log(`[nodes-repo] ✅ تم تحميل ${nodesCache.length} نود و ${levelsCache.length} دور و ${edgesCache.length} مسار من Supabase`);
      return { nodes: nodesCache, levels: levelsCache, edges: edgesCache };

    } catch (err) {
      console.error('[nodes-repo] استثناء أثناء جلب بيانات البنية التحتية:', err);
      if (nodesCache.length === 0) return loadLocalFallback();
      return { nodes: nodesCache, levels: levelsCache, edges: edgesCache };
    }
  }

  function loadLocalFallback() {
    if (window.IPS_NODES_CACHE) {
      const cache = window.IPS_NODES_CACHE;
      if (cache.levels) {
        levelsCache = JSON.parse(JSON.stringify(cache.levels));
        levelsById.clear();
        for (const l of levelsCache) levelsById.set(l.level_id, l);
      }
      if (cache.nodes) {
        nodesCache = JSON.parse(JSON.stringify(cache.nodes));
        nodesById.clear();
        nodesByUuid.clear();
        for (const n of nodesCache) {
          nodesById.set(n.node_id, n);
          if (n.esp32_uuid) nodesByUuid.set(normalizeUuid(n.esp32_uuid), n);
        }
      }
      if (cache.edges) {
        edgesCache = JSON.parse(JSON.stringify(cache.edges));
      }
      originalEdgesSnapshot = JSON.parse(JSON.stringify(edgesCache));
      resetStaged();
      isInitialized = true;
      console.log(`[nodes-repo] 📦 تم تحميل النسخة المحلية الاحتياطية (${nodesCache.length} نود، ${edgesCache.length} مسار)`);
    }
    return { nodes: nodesCache, levels: levelsCache, edges: edgesCache };
  }

  function lookupByUuid(uuid) {
    if (!uuid) return null;
    return nodesByUuid.get(normalizeUuid(uuid)) || null;
  }

  function lookupById(id) {
    const numId = Number(id);
    return nodesById.get(numId) || null;
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

  // ── المسارات المتصلة والجوار والمسافات ─────────────────────────────────────
  function getConnectedEdges(nodeId) {
    const id = Number(nodeId);
    return edgesCache.filter(e => Number(e.node_id_a) === id || Number(e.node_id_b) === id);
  }

  function getNeighborNodes(nodeId) {
    const id = Number(nodeId);
    const conns = getConnectedEdges(id);
    const neighbors = [];
    for (const e of conns) {
      const otherId = Number(e.node_id_a) === id ? Number(e.node_id_b) : Number(e.node_id_a);
      const node = lookupById(otherId);
      if (node) {
        neighbors.push({ node, edge: e });
      }
    }
    return neighbors;
  }

  function getEdgeBetween(nodeIdA, nodeIdB) {
    const a = Number(nodeIdA);
    const b = Number(nodeIdB);
    return edgesCache.find(e => 
      (Number(e.node_id_a) === a && Number(e.node_id_b) === b) ||
      (Number(e.node_id_a) === b && Number(e.node_id_b) === a)
    ) || null;
  }

  function calculateDistance(nodeA, nodeB) {
    if (!nodeA || !nodeB || nodeA.x == null || nodeB.x == null) return 0;
    const dx = Number(nodeA.x) - Number(nodeB.x);
    const dy = Number(nodeA.y) - Number(nodeB.y);
    return Math.round(Math.hypot(dx, dy));
  }

  // ── إدارة المسودة والتعديلات المحلية (Staging Actions) ──────────────────────
  async function addEdge({ nodeIdA, nodeIdB, distanceMeters = null, kind = 'walk', connectorName = null }) {
    const a = Number(nodeIdA);
    const b = Number(nodeIdB);
    const existing = getEdgeBetween(a, b);
    if (existing) {
      throw new Error(`يوجد مسار بالفعل بين النقطة #${a} والنقطة #${b}`);
    }

    const na = lookupById(a);
    const nb = lookupById(b);
    let dist = distanceMeters !== null && distanceMeters !== undefined ? Number(distanceMeters) : null;
    if (dist === null && na && nb) {
      dist = calculateDistance(na, nb);
    }

    // معرّف محلي مؤقت فريد وسالب لتمييزه عن معرّفات السيرفر
    const tempId = -Math.floor(Date.now() + Math.random() * 1000);

    const newEdge = {
      edge_id: tempId,
      node_id_a: a,
      node_id_b: b,
      distance_meters: dist,
      kind: kind || 'walk',
      connector_name: connectorName || null,
      _isStagedNew: true,
    };

    edgesCache.push(newEdge);
    stagedAddedEdges.push(newEdge);
    return newEdge;
  }

  async function deleteEdge(edgeId) {
    const id = Number(edgeId);
    const idx = edgesCache.findIndex(e => Number(e.edge_id) === id);
    if (idx === -1) return false;

    const [deleted] = edgesCache.splice(idx, 1);

    // إذا كان هذا المسار قد أُنشئ محلياً ولم يُرفع بعد، نزيله من قائمة الإضافة فقط
    const addedIdx = stagedAddedEdges.findIndex(e => Number(e.edge_id) === id);
    if (addedIdx !== -1) {
      stagedAddedEdges.splice(addedIdx, 1);
    } else {
      // مسار حقيقي على السيرفر، نضيفه لقائمة الحذف
      stagedDeletedEdgeIds.add(id);
    }

    // إزالته من التعديلات إذا كان موجوداً
    stagedUpdatedEdges.delete(id);
    return deleted;
  }

  async function updateEdge(edgeId, updates) {
    const id = Number(edgeId);
    const edge = edgesCache.find(e => Number(e.edge_id) === id);
    if (!edge) throw new Error(`المسار #${id} غير موجود`);

    Object.assign(edge, updates);

    // إذا لم يكن مساراً جديداً قيد الإضافة، نسجله في قائمة التحديثات
    const isNew = stagedAddedEdges.some(e => Number(e.edge_id) === id);
    if (!isNew) {
      const currentUpdates = stagedUpdatedEdges.get(id) || {};
      stagedUpdatedEdges.set(id, { ...currentUpdates, ...updates });
    }
    return edge;
  }

  async function splitEdge(edgeId, intermediateNodeId) {
    const id = Number(edgeId);
    const intNodeId = Number(intermediateNodeId);
    const edge = edgesCache.find(e => Number(e.edge_id) === id);
    if (!edge) throw new Error(`المسار #${id} غير موجود`);

    const nodeAId = Number(edge.node_id_a);
    const nodeBId = Number(edge.node_id_b);

    // 1. حذف المسار الأصلي
    const deletedEdge = await deleteEdge(id);

    // 2. إنشاء المسارين الجديدين
    const edge1 = await addEdge({
      nodeIdA: nodeAId,
      nodeIdB: intNodeId,
      kind: edge.kind,
      connectorName: edge.connector_name,
    });

    const edge2 = await addEdge({
      nodeIdA: intNodeId,
      nodeIdB: nodeBId,
      kind: edge.kind,
      connectorName: edge.connector_name,
    });

    return {
      deletedEdge,
      newEdges: [edge1, edge2],
    };
  }

  function hasStagedChanges() {
    return stagedAddedEdges.length > 0 || stagedDeletedEdgeIds.size > 0 || stagedUpdatedEdges.size > 0;
  }

  function getStagedSummary() {
    const addedCount = stagedAddedEdges.length;
    const deletedCount = stagedDeletedEdgeIds.size;
    const updatedCount = stagedUpdatedEdges.size;
    return {
      addedCount,
      deletedCount,
      updatedCount,
      total: addedCount + deletedCount + updatedCount,
    };
  }

  function discardStagedChanges() {
    edgesCache = JSON.parse(JSON.stringify(originalEdgesSnapshot));
    resetStaged();
    console.log('[nodes-repo] ↺ تم إلغاء كافة التعديلات في المسودة والعودة لآخر نسخة');
  }

  async function commitStagedChanges() {
    const client = getClient();
    if (!client) {
      throw new Error('Supabase client غير متاح، تعذر حفظ التغييرات على السيرفر');
    }

    const addedCount = stagedAddedEdges.length;
    const deletedCount = stagedDeletedEdgeIds.size;
    const updatedCount = stagedUpdatedEdges.size;

    // 1. حذف المسارات المحذوفة
    if (stagedDeletedEdgeIds.size > 0) {
      const idsToDelete = Array.from(stagedDeletedEdgeIds);
      const { error: delErr } = await client
        .from('edges')
        .delete()
        .in('edge_id', idsToDelete);

      if (delErr) {
        throw new Error('فشل حذف المسارات: ' + delErr.message);
      }
    }

    // 2. إدراج المسارات الجديدة
    if (stagedAddedEdges.length > 0) {
      const payload = stagedAddedEdges.map(e => ({
        node_id_a: Number(e.node_id_a),
        node_id_b: Number(e.node_id_b),
        distance_meters: e.distance_meters !== null ? Number(e.distance_meters) : null,
        kind: e.kind || 'walk',
        connector_name: e.connector_name || null,
      }));

      const { error: insErr } = await client
        .from('edges')
        .insert(payload);

      if (insErr) {
        throw new Error('فشل إدراج المسارات الجديدة: ' + insErr.message);
      }
    }

    // 3. تحديث المسارات المعدلة
    for (const [eId, updates] of stagedUpdatedEdges.entries()) {
      const { error: updErr } = await client
        .from('edges')
        .update(updates)
        .eq('edge_id', eId);

      if (updErr) {
        throw new Error(`فشل تحديث المسار #${eId}: ` + updErr.message);
      }
    }

    // 4. إعادة المزامنة لتحديث الـ IDs الحقيقية من قاعدة البيانات
    resetStaged();
    await refresh();

    return {
      added: addedCount,
      deleted: deletedCount,
      updated: updatedCount,
    };
  }

  return {
    getClient,
    refresh,
    loadLocalFallback,
    lookupByUuid,
    lookupById,
    getAllNodes,
    getLevels,
    getLevel,
    getEdges,
    isReady,
    normalizeUuid,
    getConnectedEdges,
    getNeighborNodes,
    getEdgeBetween,
    calculateDistance,
    addEdge,
    deleteEdge,
    updateEdge,
    splitEdge,
    hasStagedChanges,
    getStagedSummary,
    discardStagedChanges,
    commitStagedChanges,
  };
})();
