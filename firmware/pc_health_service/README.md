# pc_health_service

خدمة Dart CLI شغالة على الـPC في غرفة التحكم. بتقرأ بيانات صحة النودز من
ESP32 Mesh Root عبر Serial/USB، وبترفعها batch لجدول `node_health` في
Supabase. التصميم الكامل والبروتوكول في `../MESH_DESIGN.md`.

## التشغيل

```bash
cd firmware/pc_health_service
dart pub get
cp .env.example .env   # واملأ SUPABASE_SERVICE_KEY و SERIAL_PORT الصح
dart run bin/health_service.dart
```

## الحالة

هيكل أولي (skeleton) - شغال منطقيًا بس محتاج:
- [ ] اختبار فعلي مع Root حقيقي بعد ما فيرموير `IPS_Mesh_Root` يخلص
- [ ] تثبيت رقم نسخة `libserialport` الصحيح في `pubspec.yaml` بعد أول
      `dart pub get`
- [ ] retry logic لو الرفع لـSupabase فشل (الإنترنت مقطوع مؤقتًا)
- [ ] auto-detect لمنفذ الـSerial بدل الاعتماد على قيمة ثابتة في `.env`

## البنية

```
pc_health_service/
  bin/health_service.dart      # نقطة الدخول
  lib/
    config.dart                 # إعدادات + صيغة dynamic timeout
    env_loader.dart              # تحميل .env بسيط
    health_protocol.dart         # بارسر HEALTH:...
    node_health_table.dart       # جدول الحالة in-memory
    serial_reader.dart           # قراءة أسطر من الـSerial
    supabase_uploader.dart       # رفع batch عبر PostgREST
  .env.example
```
