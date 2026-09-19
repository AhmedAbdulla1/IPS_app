#pragma once

#include <stdint.h>

/**
 * serial_input.h - معالجة بروتوكول OTA على الـ Serial
 * 
 * البروتوكول:
 *   - أسطر نصية (OTA_START, OTA_END, إلخ) - بتتمرر لـ ips_serial_process_line
 *   - بيانات ثنائية (chunks الفيرموير) - بتتمرر لـ ips_serial_process_binary
 */

/**
 * تشغيل مهمة قراءة السيريال (Serial Input Task) لمعالجة أوامر الـ OTA
 */
void ips_serial_input_start(void);

/**
 * معالجة سطر نصي من السيريال (OTA_START, OTA_END, إلخ)
 */
void ips_serial_process_line(const char *line);

/**
 * معالجة بيانات ثنائية من السيريال (chunk من الفيرموير)
 */
void ips_serial_process_binary(const uint8_t *data, uint32_t len);
