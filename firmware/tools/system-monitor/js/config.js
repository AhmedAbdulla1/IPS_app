// إعدادات Supabase والنظام
// 
// ملحوظة: استخدم anon key (مش service_role) للعملاء في المتصفح
// service_role محفوظ في الـbackend بس

window.SM = window.SM || {};

SM.config = {
  // Supabase - من متغيرات البيئة أو hardcoded
  SUPABASE_URL: 'https://dqnmxlljqiqgqmntzvcx.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w',
  
  // Timeouts والمهل
  HEALTH_BASE_TIMEOUT_MS: 3000,        // Node تحتاج تبعت heartbeat كل 2s، مع مهلة 1s
  HEALTH_PER_HOP_MARGIN_MS: 800,       // كل hop إضافي = +800ms مهلة (لتأخير الشبكة)
  HIGH_HOP_THRESHOLD: 13,              // عتبة تنبيه HIGH HOP (المبنى الطبيعي حتى 12 قفزة)
  MAX_HOP_ALLOWED: 15,                 // الحد الأقصى للطبقات (مطابق للفيرموير 15)

  // Admin users (emails مسموح لهم OTA + دوال أخرى) - يمكن قراءتها من Supabase
  ADMIN_EMAILS: [
    'admin@example.com',
    'ahmed@example.com',
  ],

  // OTA settings
  OTA: {
    MAX_FILE_SIZE_MB: 2,           // حد أقصى لحجم الفيرموير
    CHUNK_SIZE: 4096,              // حجم الـchunk في الـOTA protocol
    RESPONSE_TIMEOUT_MS: 5000,     // انتظار أقصى لـرد من الـRoot
  },
};

// استخدم .env أو window.CONFIG لـ override الـdefaults
if (window.ENV) {
  Object.assign(SM.config, window.ENV);
}
