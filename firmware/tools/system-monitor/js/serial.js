// الاتصال بالـRoot عبر Web Serial API وقراءة أسطر health (JSON من
// الـRoot الفعلي + HEALTH:... كصيغة قديمة/fallback). بروتوكول النقل
// نفسه موثّق في ../../../MESH_DESIGN.md، والتنفيذ المرجعي الشغال فعليًا
// في ../../pc_health_service/lib/health_protocol.dart.
//
// الوحدة دي مالهاش أي علاقة بالـDOM مباشرة - بس بتستقبل بيانات وتنادي
// الـcallbacks اللي اتسجلت من dashboard.js. كده أي حد يقدر يستخدمها من
// غير ما يتقيد بشكل الصفحة.

window.SM = window.SM || {};

SM.serial = (function () {
  let port = null;
  let reader = null;
  let writer = null;
  let keepReading = false;
  let incomingBuffer = "";

  const onHealthLine = []; // (nodeIdHex, hopCount, status, fwMajor, fwMinor) => void
  const onRawLine = [];    // (line) => void
  const onConnectionChange = []; // (connected: boolean) => void

  function fire(list, ...args) {
    for (const cb of list) {
      try {
        cb(...args);
      } catch (e) {
        console.error("SM.serial listener error", e);
      }
    }
  }

  function parseLine(line) {
    line = line.trim();
    if (!line) return;

    // الصيغة الفعلية اللي بيبعتها الـRoot دلوقتي (راجع
    // IPS_Mesh_Root/main/serial_output.c):
    // {"type":"health","node_id":"<hex>","status":"online|offline",
    //  "hop_count":N,"last_seen_ms":N}
    // لازم تتبارس الأول - نفس ترتيب الأولوية المتفق عليه في
    // pc_health_service/lib/health_protocol.dart (المرجع الشغال فعليًا
    // مع نفس الـRoot)، عشان الأداتين ميختلفوش في تفسير نفس البيانات.
    if (line.startsWith("{") && line.endsWith("}")) {
      try {
        const data = JSON.parse(line);
        if (data.node_id && data.hop_count !== undefined) {
          const nodeIdHex = String(data.node_id).toLowerCase();
          const hopCount = parseInt(data.hop_count, 10);
          const status = data.status || "online";
          const fwMajor = data.fw_major !== undefined ? parseInt(data.fw_major, 10) : null;
          const fwMinor = data.fw_minor !== undefined ? parseInt(data.fw_minor, 10) : null;
          fire(onHealthLine, nodeIdHex, hopCount, status, fwMajor, fwMinor);
          return;
        }
      } catch (_) {
        // مش JSON صالح - نكمل ونجرب الصيغة القديمة تحت
      }
    }

    // صيغة قديمة/احتياطية HEALTH:<uid_hex>:<online|offline>:<hop_count>:<last_seen_ms>
    if (line.startsWith("HEALTH:")) {
      const parts = line.substring(7).split(":");
      if (parts.length >= 3) {
        const nodeIdHex = parts[0].toLowerCase();
        const status = parts[1];
        const hopCount = parseInt(parts[2], 10);
        fire(onHealthLine, nodeIdHex, hopCount, status, null, null);
        return;
      }
    }

    fire(onRawLine, line);
  }

  async function connect() {
    if (!("serial" in navigator)) {
      throw new Error(
        "المتصفح ده مش بيدعم Web Serial. افتح الصفحة في Chrome أو Edge."
      );
    }

    port = await navigator.serial.requestPort();
    await port.open({ baudRate: SM.config.SERIAL_BAUD_RATE });

    const textDecoder = new TextDecoderStream();
    port.readable.pipeTo(textDecoder.writable);
    reader = textDecoder.readable.getReader();

    const textEncoder = new TextEncoderStream();
    textEncoder.readable.pipeTo(port.writable);
    writer = textEncoder.writable.getWriter();

    keepReading = true;
    readLoop();
    fire(onConnectionChange, true);
  }

  async function readLoop() {
    while (keepReading) {
      try {
        const { value, done } = await reader.read();
        if (done) break;
        if (value) {
          incomingBuffer += value;
          const lines = incomingBuffer.split("\n");
          incomingBuffer = lines.pop(); // سيب السطر الناقص للمرة الجاية
          for (const line of lines) parseLine(line);
        }
      } catch (e) {
        fire(onRawLine, "خطأ قراءة Serial: " + e.message);
        break;
      }
    }
  }

  async function disconnect() {
    keepReading = false;
    try {
      if (reader) {
        await reader.cancel();
        reader.releaseLock();
      }
      if (writer) await writer.close();
      if (port) await port.close();
    } catch (_) {
      /* تجاهل أخطاء الإغلاق */
    }
    port = null;
    reader = null;
    writer = null;
    fire(onConnectionChange, false);
  }

  /** بيبعت نص خام (مثلاً أوامر SET_ID) - مستخدمة كمان في التحكم اليدوي لو احتجنا. */
  async function writeText(text) {
    if (!writer) throw new Error("مش متصل بالـSerial.");
    await writer.write(text);
  }

  /** بيبعت بايتات خام (هيتستخدم لاحقًا لنقل ملف الفيرموير وقت OTA - راجع ota.js). */
  async function writeRawBytes(_bytes) {
    throw new Error(
      "writeRawBytes لسه مش متنفذة - محتاجة TextEncoderStream بديل يقبل" +
        " Uint8Array مباشرة (الـstream الحالي نصي بس). راجع ota.js."
    );
  }

  return {
    connect,
    disconnect,
    writeText,
    writeRawBytes,
    isConnected: () => port !== null,
    onHealthLine: (cb) => onHealthLine.push(cb),
    onRawLine: (cb) => onRawLine.push(cb),
    onConnectionChange: (cb) => onConnectionChange.push(cb),
  };
})();
