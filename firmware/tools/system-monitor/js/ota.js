// js/ota.js — Over-The-Air Firmware Distribution via Web Serial & ESP-MESH

window.SM = window.SM || {};

SM.ota = (function () {
  const CHUNK_SIZE = 4096; // 4KB chunks
  const RESPONSE_TIMEOUT_MS = 8000;

  async function calculateSHA256(arrayBuffer) {
    const hashBuffer = await crypto.subtle.digest('SHA-256', arrayBuffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  }

  async function waitForResponse(expectedPrefix, timeoutMs = RESPONSE_TIMEOUT_MS) {
    return new Promise((resolve, reject) => {
      let unsubscribe = null;
      const receivedLines = [];

      const timeoutId = setTimeout(() => {
        if (typeof unsubscribe === "function") unsubscribe();
        const logsText = receivedLines.length > 0
          ? `\nRecent lines received over Serial:\n[ ${receivedLines.join(' | ')} ]`
          : '\n(No serial data received during timeout window)';
        reject(new Error(`Timeout waiting for response (${expectedPrefix})${logsText}`));
      }, timeoutMs);

      const listener = (rawLine) => {
        const line = rawLine ? rawLine.trim() : '';
        if (!line) return;

        receivedLines.push(line);
        if (receivedLines.length > 10) receivedLines.shift();

        if (line.includes(expectedPrefix)) {
          clearTimeout(timeoutId);
          if (typeof unsubscribe === "function") unsubscribe();
          resolve(line);
        } else if (line.includes('OTA_ERROR:') || line.includes('ERROR:')) {
          clearTimeout(timeoutId);
          if (typeof unsubscribe === "function") unsubscribe();
          reject(new Error(`Root gateway error: ${line}`));
        }
      };

      unsubscribe = SM.serial.onRawLine(listener);
    });
  }

  async function sendFirmware(file, onProgress) {
    if (!SM.serial.isConnected()) {
      throw new Error('Please connect to Root Gateway via Serial first');
    }

    const bytes = new Uint8Array(await file.arrayBuffer());
    const size = bytes.length;
    const sha256Hex = await calculateSHA256(bytes);
    const targetMajor = document.getElementById("targetFwMajor")?.value?.trim();
    const targetMinor = document.getElementById("targetFwMinor")?.value?.trim();
    let version = "";

    if (targetMajor && targetMinor) {
      version = `${targetMajor}.${targetMinor}`;
    } else {
      // Extract firmware version from ESP image header (esp_app_desc_t at offset 0x20)
      if (bytes.length >= 80 && bytes[32] === 0x32 && bytes[33] === 0x54 && bytes[34] === 0xcd && bytes[35] === 0xab) {
        let str = "";
        for (let i = 48; i < 80; i++) {
          if (bytes[i] === 0) break;
          str += String.fromCharCode(bytes[i]);
        }
        if (str.trim()) version = str.trim();
      }
      if (!version) {
        version = file.name.replace(/\.bin$/i, "").slice(0, 31);
      }
    }

    console.log(`[ota] Binary: ${file.name}, Size: ${size} bytes, Version: ${version}`);
    console.log(`[ota] SHA256: ${sha256Hex}`);

    // Step 1: Send OTA_START
    const startCmd = `OTA_START:${size}:${sha256Hex}:${version}\n`;
    await SM.serial.writeText(startCmd);
    console.log(`[ota] Sent: ${startCmd.trim()}`);

    // Step 2: Wait for OTA_READY
    const readyResponse = await waitForResponse('OTA_READY', 10000);
    console.log(`[ota] Received: ${readyResponse}`);

    // Step 3: Stream chunks
    for (let offset = 0; offset < size; offset += CHUNK_SIZE) {
      const chunkSize = Math.min(CHUNK_SIZE, size - offset);
      const chunk = bytes.slice(offset, offset + chunkSize);

      await SM.serial.writeRawBytes(chunk);

      const progressLine = await waitForResponse('OTA_PROGRESS', 8000);
      const match = progressLine.match(/OTA_PROGRESS:(\d+)/);
      if (match) {
        const received = parseInt(match[1], 10);
        const percent = Math.round((received / size) * 100);
        onProgress?.(percent, received, size);
      }
    }

    // Step 4: Send OTA_END
    await SM.serial.writeText('OTA_END\n');
    console.log(`[ota] Sent: OTA_END`);

    // Step 5: Wait for OTA_DONE
    const doneResponse = await waitForResponse('OTA_DONE', 15000);
    console.log(`[ota] Received: ${doneResponse}`);
    return { size, version };
  }

  async function redistributeFirmware() {
    if (!SM.serial.isConnected()) {
      throw new Error('Please connect to Root Gateway via Serial first');
    }
    await SM.serial.redistributeFirmware();
    const resp = await waitForResponse('OTA_RELAY_STARTED', 8000);
    console.log('[ota] Firmware redistribution initiated:', resp);
    return resp;
  }

  return {
    sendFirmware,
    redistributeFirmware,
  };
})();
