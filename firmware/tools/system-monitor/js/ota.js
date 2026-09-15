// رفع فيرموير جديد للـRoot - محجوب عن غير الـadmin (يتفعّل من dashboard.js
// بعد التأكد من SM.auth.isAdmin()).
//
// ⚠️ حالة التنفيذ: واجهة المستخدم (اختيار ملف + زرار الرفع + شريط تقدم)
// شغالة، لكن بروتوكول النقل الفعلي عبر الـSerial *لسه مش متفق عليه*
// (راجع OTA_PLAN.md - القرار المعماري المفتوح). الدالة sendFirmware
// تحت فيها TODO واضح لمكان الوصل لما نحدد البروتوكول ونكتب الاستقبال
// المقابل في IPS_Mesh_Root.

window.SM = window.SM || {};

SM.ota = (function () {
  async function sendFirmware(file, onProgress) {
    if (!SM.auth.isAdmin()) {
      throw new Error("محتاج صلاحية admin عشان ترفع فيرموير.");
    }
    if (!SM.serial.isConnected()) {
      throw new Error("لازم تتصل بالـRoot الأول (زرار الاتصال فوق).");
    }

    const bytes = new Uint8Array(await file.arrayBuffer());

    // -----------------------------------------------------------------
    // TODO (بعد ما يتحدد بروتوكول النقل في OTA_PLAN.md):
    //   1. ابعت أمر بداية يوضّح الحجم الكلي + اسم/نسخة الفيرموير، مثلاً
    //      "OTA_START:<size>:<version>\n"
    //   2. قسّم bytes لـchunks (مثلاً 4KB) وابعتهم واحد واحد عن طريق
    //      SM.serial.writeRawBytes(chunk) (لسه محتاجة تتنفذ - الـstream
    //      الحالي في serial.js نصي بس مش بايتات خام)
    //   3. استنى تأكيد (ACK) من الـRoot بعد كل chunk قبل ما تبعت اللي
    //      بعده (السيريال مفيهوش flow control تلقائي)
    //   4. في الآخر ابعت "OTA_END:<sha256>\n" والـRoot يتأكد من التطابق
    //      قبل ما يعمل esp_ota_set_boot_partition
    //   5. الـRoot بعد كده يوزّع نفس الفيرموير على الـNodes عبر
    //      esp_mesh_lite_transmit_file_start (مكتوبة أصلًا في مكتبة
    //      mesh_lite - محتاجة provide_file_cb/get_file_cb في الكود بتاعنا،
    //      راجع OTA_PLAN.md).
    // -----------------------------------------------------------------
    throw new Error(
      "بروتوكول رفع الفيرموير لسه مش متنفذ (TODO في ota.js + كود " +
        "الاستقبال في IPS_Mesh_Root). راجع OTA_PLAN.md للتفاصيل."
    );
  }

  return { sendFirmware };
})();
