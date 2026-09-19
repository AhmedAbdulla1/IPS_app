// js/serial.js — إدارة اتصال Web Serial مع ESP32 Root
// يدعم قراءة رسائل الصحة (health)، معلومات الـ Root، وأوامر OTA الثنائية والنصية

window.SM = window.SM || {};

SM.serial = (function () {
  let port = null;
  let reader = null;
  let isConnected = false;
  let portInfo = 'Web Serial';

  const connectionChangeCallbacks = [];
  const healthLineCallbacks = [];
  const rootInfoCallbacks = [];
  const rawLineCallbacks = [];

  const textEncoder = new TextEncoder();
  const textDecoder = new TextDecoder();

  async function connect() {
    try {
      if (!navigator.serial) {
        throw new Error('متصفحك لا يدعم Web Serial API. يرجى استخدام متصفح Chrome أو Edge أو Opera.');
      }

      port = await navigator.serial.requestPort();
      await port.open({ baudRate: 115200 });

      const info = port.getInfo ? port.getInfo() : {};
      if (info.usbVendorId) {
        portInfo = `USB (VID:${info.usbVendorId.toString(16).padStart(4, '0')})`;
      } else {
        portInfo = 'Serial Port';
      }

      isConnected = true;
      console.log('[serial] ✅ متصل بـ Root على ' + portInfo);
      
      notifyConnectionChange(true);
      startReading();

      // طلب معلومات الـ Root فور الاتصال
      setTimeout(() => {
        requestRootInfo().catch(() => {});
      }, 500);

    } catch (error) {
      console.error('[serial] ❌ خطأ الاتصال:', error);
      throw error;
    }
  }

  async function disconnect() {
    if (reader) {
      try {
        await reader.cancel();
      } catch (e) {}
      reader = null;
    }
    if (port) {
      try {
        await port.close();
      } catch (e) {}
      port = null;
    }
    isConnected = false;
    console.log('[serial] اتصال مقطوع');
    notifyConnectionChange(false);
  }

  async function startReading() {
    if (!port || !port.readable) {
      console.error('[serial] ❌ port مش readable');
      return;
    }

    reader = port.readable.getReader();
    const buffer = new Uint8Array(65536);
    let bufferIndex = 0;

    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        for (let i = 0; i < value.length; i++) {
          buffer[bufferIndex++] = value[i];

          if (value[i] === 0x0A) { // '\n'
            const line = textDecoder.decode(buffer.slice(0, bufferIndex - 1));
            bufferIndex = 0;
            processLine(line.trim());
          }
        }
      }
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('[serial] خطأ قراءة:', error);
        await disconnect();
      }
    }
  }

  function processLine(line) {
    if (!line) return;

    // 1. فحص هل هو JSON
    if (line.startsWith('{')) {
      try {
        const obj = JSON.parse(line);
        if (obj.type === 'root_info') {
          rootInfoCallbacks.forEach(cb => cb(obj));
          rawLineCallbacks.forEach(cb => cb(line));
          return;
        }
        if (obj.type === 'health' || obj.node_id || obj.node_id_hex) {
          const update = {
            nodeIdHex: (obj.node_id || obj.node_id_hex || '').replace(/[^a-fA-F0-9]/g, '').toLowerCase(),
            status: obj.status || 'online',
            hopCount: typeof obj.hop_count === 'number' ? obj.hop_count : parseInt(obj.hop_count || 0, 10),
            fwMajor: typeof obj.fw_major === 'number' ? obj.fw_major : (obj.fw_major !== undefined ? parseInt(obj.fw_major, 10) : null),
            fwMinor: typeof obj.fw_minor === 'number' ? obj.fw_minor : (obj.fw_minor !== undefined ? parseInt(obj.fw_minor, 10) : null),
            timestamp: obj.last_seen_ms || Date.now(),
            receivedAt: Date.now(),
          };
          healthLineCallbacks.forEach(cb =>
            cb(update.nodeIdHex, update.hopCount, update.status, update.fwMajor, update.fwMinor, update)
          );
          rawLineCallbacks.forEach(cb => cb(line));
          return;
        }
      } catch (e) {}
    }

    // 2. فحص البروتوكول التقليدي HEALTH:...
    let update = null;
    if (SM.protocol?.parse) {
      update = SM.protocol.parse(line);
    }
    if (update && update.nodeIdHex) {
      healthLineCallbacks.forEach(cb => 
        cb(update.nodeIdHex, update.hopCount, update.status, update.fwMajor, update.fwMinor, update)
      );
    }

    // إرسال كافة الأسطر للسجل
    rawLineCallbacks.forEach(cb => cb(line));
  }

  async function writeText(text) {
    if (!isConnected || !port || !port.writable) {
      throw new Error('Serial port not connected');
    }

    const writer = port.writable.getWriter();
    await writer.write(textEncoder.encode(text));
    writer.releaseLock();
  }

  async function writeRawBytes(bytes) {
    if (!isConnected || !port || !port.writable) {
      throw new Error('Serial port not connected');
    }

    const writer = port.writable.getWriter();
    await writer.write(bytes);
    writer.releaseLock();
  }

  async function requestRootInfo() {
    if (isConnected) {
      await writeText('GET_ROOT_INFO\n');
    }
  }

  async function redistributeFirmware() {
    if (!isConnected) {
      throw new Error('يجب الاتصال بـ Root أولاً عبر السيريال');
    }
    await writeText('OTA_REDISTRIBUTE\n');
  }

  function onConnectionChange(callback) {
    connectionChangeCallbacks.push(callback);
  }

  function onRootInfo(callback) {
    rootInfoCallbacks.push(callback);
  }

  function onHealthLine(callback) {
    healthLineCallbacks.push(callback);
    return () => {
      const idx = healthLineCallbacks.indexOf(callback);
      if (idx !== -1) healthLineCallbacks.splice(idx, 1);
    };
  }

  function onRawLine(callback) {
    rawLineCallbacks.push(callback);
    return () => {
      const idx = rawLineCallbacks.indexOf(callback);
      if (idx !== -1) rawLineCallbacks.splice(idx, 1);
    };
  }

  function notifyConnectionChange(connected) {
    connectionChangeCallbacks.forEach(cb => cb(connected));
  }

  return {
    connect,
    disconnect,
    writeText,
    writeRawBytes,
    requestRootInfo,
    redistributeFirmware,
    onConnectionChange,
    onRootInfo,
    onHealthLine,
    onRawLine,
    isConnected: () => isConnected,
    getPortInfo: () => portInfo,
  };
})();
