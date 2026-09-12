#pragma once

// أوامر SET_ID/GET_ID عبر الـSerial (نفس فلسفة الفيرموير الأصلي).
// بيشتغل كـFreeRTOS task مستقل بيستنى أسطر من stdin (UART0/USB).

void provisioning_task_start(void);
