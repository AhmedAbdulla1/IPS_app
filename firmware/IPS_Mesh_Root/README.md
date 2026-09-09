# IPS_Mesh_Root

فيرموير الـRoot node - ESP-IDF (مش Arduino). التصميم الكامل في
`../MESH_DESIGN.md`، وحالة التنفيذ في `../MESH_PROGRESS.md`.

## البناء

```bash
idf.py set-target esp32
idf.py build
idf.py -p COMx flash monitor
```

أول `idf.py build` هينزّل component `espressif/mesh_lite` تلقائيًا
(component manager) حسب `main/idf_component.yml`.

## الحالة الحالية

هيكل أولي شغال منطقيًا للـinit sequence (WiFi/NVS/bridge netif/mesh_lite
start) والـSerial output. **مش مكتمل بعد** - أهم نقطة ناقصة:

- استقبال البيانات الخام (heartbeat) من الـchild nodes - الـAPI بالظبط
  محتاج تأكيد من `components/mesh_lite/include/esp_mesh_lite.h` بعد أول
  تنزيل للـcomponent (شوف TODO في `main/mesh_bridge.c`)

راجع `main/mesh_bridge.c` للتفاصيل والـTODOs المفتوحة.
