# IPS_Mesh_Node

فيرموير الـNode الفعلي (positioning beacon + مشارك في شبكة الـhealth).
**ESP-IDF native بالكامل** - مفيش Arduino. راجع `../MESH_DESIGN.md` للتصميم
الكامل، و`../MESH_PROGRESS.md` للحالة.

## ليه مفيش Arduino؟

كانت الخطة الأولى تستخدم "Arduino as an ESP-IDF component" عشان نحافظ
على كود الـBLE الموجود. بس `arduino-esp32` لسه مش بيدعم ESP-IDF v6.x
رسميًا (النسخة المتوافقة لسه alpha وناقصة مكونات). بما إن كود الـBLE
advertising بسيط (مفيش GATT/اتصالات)، اتقرر نعيد كتابته مباشرة بـNimBLE
(المكوّن `bt` المدمج في ESP-IDF نفسه) - كده مفيش تبعية خارجية غير
`mesh_lite`، والمشروع شغال على أي نسخة ESP-IDF نضيفة من غير تعقيد.

الكود الأصلي (محاولة Arduino) محفوظ في `main/_legacy_arduino_attempt/`
كمرجع بس - مش جزء من الـbuild.

## البناء

```bash
idf.py set-target esp32
idf.py build
idf.py -p COMx flash monitor
```

## البنية

```
main/
  main.c                 # app_main - ينسّق كل حاجة
  config.h                # كل القيم المشتركة (BLE + mesh)
  node_id_store.c/.h      # تحميل/حفظ node_id من NVS
  ble_node.c/.h           # NimBLE advertising (منقول منطقيًا من الأصلي)
  provisioning.c/.h       # أوامر SET_ID/GET_ID عبر Serial (task مستقل)
  mesh_participant.c/.h   # مشاركة mesh_lite + heartbeat (placeholder)
```

## الحالة الحالية

- **BLE advertising:** أعيد كتابته بـNimBLE، نفس صيغة الـpayload
  ونفس الـCompany ID (0xFFFF) بالظبط زي الأصلي.
- **Provisioning (SET_ID/GET_ID):** أعيد كتابته على NVS مباشرة (نفس
  namespace/key اللي كانت الـPreferences library بتستخدمها) - النودز
  المُجهزة قبل كده المفروض تفضل شغالة من غير إعادة تجهيز، بس **ده لسه
  مش مُختبر فعليًا**.
- **mesh_lite participation:** init sequence جاهز، heartbeat لسه
  placeholder (TODO حرج - راجع `mesh_participant.c`).
- **BLE/WiFi coexistence:** لسه مش مفعّل - TODO في `sdkconfig.defaults`،
  **أولوية حرجة قبل أي اختبار ميداني**.

## مخاطر لازم تنتبهلها وقت أول build

- اسم دالة init الخاصة بـNimBLE HCI ممكن يكون اتغيّر شوية بين نسخ
  ESP-IDF - راجع TODO في `ble_node.c` (`ble_node_start`).
- تعارض محتمل بين `nvs_flash_init`/`esp_netif_init`/`esp_event_loop_create_default`
  المتكررين في `main.c` و`mesh_participant.c` - اتحوط بتجاهل
  `ESP_ERR_INVALID_STATE`، محتاج تأكيد عملي.
