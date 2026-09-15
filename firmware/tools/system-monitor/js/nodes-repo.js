// جلب بيانات النودز الوصفية (الاسم/الدور) من جدول nodes في Supabase،
// وربطها بالـuuid اللي بييجي في رسائل HEALTH: (32 حرف hex من غير
// شرطات) - عمود esp32_uuid في Supabase من نوع uuid فبييجي بشرطات
// (8-4-4-4-12)، فمحتاجين نطبّع الاتنين لنفس الشكل قبل المقارنة.

window.SM = window.SM || {};

SM.nodesRepo = (function () {
  // Map<normalizedUuidHex, {node_id, name_ar, name_en, level_id, x, y}>
  let cache = new Map();
  let lastFetchError = null;

  function normalizeUuid(uuid) {
    if (!uuid) return "";
    return uuid.replace(/-/g, "").toLowerCase();
  }

  async function refresh() {
    const { data, error } = await SM.supabaseClient
      .from("nodes")
      .select("node_id, name_ar, name_en, level_id, x, y, esp32_uuid")
      .not("esp32_uuid", "is", null);

    if (error) {
      lastFetchError = error.message;
      console.error("فشل جلب بيانات النودز من Supabase:", error.message);
      return;
    }

    lastFetchError = null;
    const next = new Map();
    for (const row of data) {
      next.set(normalizeUuid(row.esp32_uuid), row);
    }
    cache = next;
  }

  /** بيرجع بيانات النود المسجلة في Supabase، أو null لو مش مسجلة لسه. */
  function lookup(nodeIdHex) {
    return cache.get(normalizeUuid(nodeIdHex)) || null;
  }

  return { refresh, lookup, getLastError: () => lastFetchError };
})();
