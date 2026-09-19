// التحقق من المستخدم (Supabase Auth)
// 
// Roles:
// - "anon": مستخدم بدون تسجيل (عرض فقط)
// - "admin": مستخدم مسجّل + email في قائمة ADMIN_EMAILS (أوامر OTA وإدارة)

window.SM = window.SM || {};

SM.auth = (function () {
  const changeCallbacks = [];
  let supabase = null;
  let currentUser = null;
  let userRole = 'anon';

  async function init() {
    try {
      // initialize Supabase client
      if (!window.supabase) {
        console.warn('[auth] Supabase JS SDK غير محمل');
        return;
      }
      const { createClient } = window.supabase;
      supabase = createClient(
        SM.config.SUPABASE_URL,
        SM.config.SUPABASE_ANON_KEY
      );

      // check existing session
      const { data, error } = await supabase.auth.getSession();
      if (error) {
        console.error('[auth] خطأ في جلب الـsession:', error);
        return;
      }

      if (data?.session?.user) {
        await setUser(data.session.user);
      }

      // listen for auth changes
      supabase.auth.onAuthStateChange(async (event, session) => {
        if (session?.user) {
          await setUser(session.user);
        } else {
          clearUser();
        }
      });
    } catch (err) {
      console.error('[auth] خطأ في تهيئة Supabase Auth:', err);
    }
  }

  async function setUser(user) {
    currentUser = user;
    
    // -------------------------------------------------------------------------
    // [ملاحظة مهمة لبيئة التطوير والاختبار المحلي]:
    // تم تفعيل صلاحية Admin تلقائيًا لأي مستخدم يسجل دخوله لتسهيل الاختبار وظهور لوحة الـ OTA مباشرة.
    // 
    // [ما يجب تغييره عند الانتقال للإنتاج Production]:
    // استبدل السطر التالي بالتحقق الصارم إما عبر جدول admins في Supabase:
    //   const { data } = await supabase.from('admins').select('role').eq('user_id', user.id).maybeSingle();
    //   const isAdmin = data && data.role === 'admin';
    // أو عبر قائمة الإيميلات المصرح لها فقط:
    //   const isAdmin = SM.config.ADMIN_EMAILS.includes(user.email);
    // -------------------------------------------------------------------------
    const isAdmin = true;
    userRole = isAdmin ? 'admin' : 'user';

    console.log(`[auth] ✅ مسجّل: ${user.email} (${userRole})`);
    notifyChange();
  }

  function clearUser() {
    currentUser = null;
    userRole = 'anon';
    console.log('[auth] ❌ خروج');
    notifyChange();
  }

  async function signIn(email, password) {
    if (!supabase) {
      throw new Error('Supabase not initialized');
    }

    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      throw error;
    }

    // user set automatically via onAuthStateChange
  }

  async function signOut() {
    if (!supabase) return;

    const { error } = await supabase.auth.signOut();
    if (error) {
      console.error('[auth] خطأ الخروج:', error);
      return;
    }

    // cleared automatically via onAuthStateChange
  }

  function onChange(callback) {
    changeCallbacks.push(callback);
  }

  function notifyChange() {
    changeCallbacks.forEach(cb => cb({ user: currentUser, role: userRole }));
  }

  return {
    init,
    signIn,
    signOut,
    onChange,
    getUser: () => currentUser,
    getRole: () => userRole,
    isAdmin: () => userRole === 'admin',
    isLoggedIn: () => currentUser !== null,
  };
})();
