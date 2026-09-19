#pragma once

// استقبال فيرموير جديد جاي عبر الـmesh (من الـRoot، بعد ما هو ذات نفسه
// استقبله من الـPC - راجع IPS_Mesh_Root/main/ota_receiver.c). التطبيق
// الفعلي وإعادة التشغيل بتتم أوتوماتيك من مكتبة mesh_lite نفسها عن
// طريق الـcallbacks المسجّلة هنا.

/** لازم تتنادى مرة واحدة وقت تشغيل الـNode (من main.c، بعد mesh_participant_setup). */
void ota_apply_init(void);
