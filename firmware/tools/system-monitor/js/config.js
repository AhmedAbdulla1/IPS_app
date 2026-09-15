// إعدادات عامة لأداة System Monitor. مفيش أي أسرار هنا - الـanon key
// آمن للعرض في المتصفح دايمًا (الحماية شغالة عن طريق RLS في Supabase
// + Supabase Auth، مش عن طريق إخفاء المفتاح ده).
//
// ملحوظة: ده مختلف تمامًا عن ips_node_provisioning_tool.html اللي
// بيستخدم service_role key (سري، خطر) - الأداة دي "للحكم عامة" فمينفعش
// تستخدم نفس الأسلوب.
//
// ملحوظة تقنية: مفيش ES modules هنا عمدًا - عشان الأداة تفضل تشتغل لو
// اتفتحت مباشرة (file://) من غير سيرفر محلي (الـmodules بتترفض بسبب
// CORS في السيناريو ده). كل ملف بيضيف حاجته لنفس الـnamespace العام
// window.SM بترتيب التحميل في index.html.

window.SM = window.SM || {};

SM.config = {
  SUPABASE_URL: "https://dqnmxlljqiqgqmntzvcx.supabase.co",
  SUPABASE_ANON_KEY:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w",

  // حساب الـtimeout المسموح بيه لكل node حسب بعده عن الـRoot (hop count) -
  // كل hop إضافي بياخد وقت أطول شوية عشان heartbeat يوصل، فبنضيف هامش.
  HEALTH_BASE_TIMEOUT_MS: 3000,
  HEALTH_PER_HOP_MARGIN_MS: 800,

  SERIAL_BAUD_RATE: 115200,
};
