#pragma once

#include <stdbool.h>
#include <stdint.h>

/* marks vitals field as a valid measurement. */
#define BLE_VITAL_VALID_HEART_RATE (1U << 0)
#define BLE_VITAL_VALID_SPO2 (1U << 1)
#define BLE_VITAL_VALID_TEMPERATURE (1U << 2)

/* vitals reading */
typedef struct {
    uint32_t timestamp_ms;
    uint16_t sequence;
    int16_t temperature_centi_c;
    uint8_t heart_rate_bpm;
    uint8_t spo2_percent;
    uint8_t valid_flags;
} ble_vitals_t;

void ble_init(void);
int ble_publish_vitals(const ble_vitals_t *vitals);
bool ble_is_connected(void);
bool ble_is_encrypted(void);
bool ble_notifications_enabled(void);
