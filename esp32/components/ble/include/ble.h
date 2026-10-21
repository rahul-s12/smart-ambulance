#pragma once

#include <stdbool.h>
#include <stdint.h>

#define BLE_VITAL_VALID_HEART_RATE (1U << 0)
#define BLE_VITAL_VALID_SPO2 (1U << 1)
#define BLE_VITAL_VALID_TEMPERATURE (1U << 2)

typedef struct {
    uint32_t timestamp_ms;
    uint16_t sequence;
    int16_t temperature_centi_c;
    uint8_t heart_rate_bpm;
    uint8_t spo2_percent;
    uint8_t valid_flags;
} ble_vitals_t;

void ble_init(void);
int ble_publish_vitals(const ble_vitals_t *reading);
bool ble_is_connected(void);
bool ble_is_encrypted(void);
bool ble_notifications_enabled(void);

/* Internal component hooks used by ble_gap.c and ble_gatt.c. */
void smart_ble_gap_init(void);
void ble_gap_start_advertising(void);
uint16_t ble_gap_connection_handle(void);
bool ble_gap_is_encrypted(void);
bool ble_gap_is_live_subscribed(void);
bool ble_gap_is_control_subscribed(void);
bool ble_gap_is_stream_enabled(void);
void ble_gap_set_stream_enabled(bool enabled);
int ble_gatt_init(void);
bool ble_gatt_is_live_handle(uint16_t handle);
bool ble_gatt_is_control_handle(uint16_t handle);
int ble_gatt_publish_reading(const ble_vitals_t *reading);