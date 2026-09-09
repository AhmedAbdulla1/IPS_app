#pragma once

// إخراج بروتوكول HEALTH:... على الـSerial (UART0/USB) اللي بيتقرا من
// pc_health_service. الصيغة موثقة في MESH_DESIGN.md §6.

// بيبدأ FreeRTOS task دوري بيلف على جدول health_table ويطبع سطر
// HEALTH: لكل node معروفة كل IPS_HEALTH_REPORT_INTERVAL_MS.
void ips_serial_output_start(void);
