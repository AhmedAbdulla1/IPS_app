// تسجيل الدخول والتحقق من الصلاحيات (admin / viewer) عن طريق Supabase
// Auth + جدول admins. المراقبة نفسها مفتوحة للكل من غير تسجيل دخول -
// الدخول مطلوب بس عشان تظهر لوحة "رفع فيرموير جديد".

window.SM = window.SM || {};

SM.supabaseClient = window.supabase.createClient(
  SM.config.SUPABASE_URL,
  SM.config.SUPABASE_ANON_KEY
);

SM.auth = (function () {
  let currentUser = null;
  let currentRole = null; // 'admin' | 'viewer' | null (لسه مش مسجل دخول)
  const listeners = [];

  function notify() {
    for (const cb of listeners) {
      try {
        cb({ user: currentUser, role: currentRole });
      } catch (e) {
        console.error("SM.auth listener error", e);
      }
    }
  }

  async function refreshRole() {
    if (!currentUser) {
      currentRole = null;
      return;
    }
    const { data, error } = await SM.supabaseClient
      .from("admins")
      .select("role")
      .eq("user_id", currentUser.id)
      .maybeSingle();

    if (error) {
      console.error("فشل جلب الصلاحية:", error.message);
      currentRole = null;
      return;
    }
    // لو المستخدم عمل login بس مش مسجل في جدول admins أصلاً، معاملة
    // "viewer" ضمنيًا (مش admin على أي حال) - مفيش صلاحيات رفع.
    currentRole = data ? data.role : "viewer";
  }

  async function init() {
    const { data } = await SM.supabaseClient.auth.getSession();
    currentUser = data.session ? data.session.user : null;
    await refreshRole();
    notify();

    SM.supabaseClient.auth.onAuthStateChange(async (_event, session) => {
      currentUser = session ? session.user : null;
      await refreshRole();
      notify();
    });
  }

  async function signIn(email, password) {
    const { error } = await SM.supabaseClient.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw error;
  }

  async function signOut() {
    await SM.supabaseClient.auth.signOut();
  }

  function onChange(cb) {
    listeners.push(cb);
  }

  function isAdmin() {
    return currentRole === "admin";
  }

  return { init, signIn, signOut, onChange, isAdmin };
})();
