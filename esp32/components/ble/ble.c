#include "esp_err.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "host/ble_hs.h"
#include "host/ble_store.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "services/gap/ble_svc_gap.h"

#include "ble.h"

#define BLE_DEVICE_NAME "Smart_Ambulance"
static const char *const tag = "smart_ambulance_ble";

void ble_store_config_init(void);

static void host_task(void *parameter)
{
    (void)parameter;
    nimble_port_run();
    nimble_port_freertos_deinit();
}

static void simulated_vitals_task(void *parameter)
{
    (void)parameter;
    uint16_t sequence = 0;
    uint8_t phase = 0;
    for (;;) {
        const ble_vitals_t vitals = {
            .timestamp_ms = (uint32_t)(esp_timer_get_time() / 1000),
            .sequence = sequence++,
            .temperature_centi_c = (int16_t)(3670 + (phase % 7) * 2),
            .heart_rate_bpm = (uint8_t)(72 + (phase % 9)),
            .spo2_percent = (uint8_t)(97 + (phase % 3)),
            .valid_flags = BLE_VITAL_VALID_HEART_RATE | BLE_VITAL_VALID_SPO2 |
                           BLE_VITAL_VALID_TEMPERATURE,
        };
        (void)ble_publish_vitals(&vitals);
        phase++;
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void ble_init(void)
{
    esp_err_t result = nvs_flash_init();
    if (result == ESP_ERR_NVS_NO_FREE_PAGES || result == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        result = nvs_flash_init();
    }
    if (result != ESP_OK) {
        ESP_LOGE(tag, "NVS initialisation failed: %s", esp_err_to_name(result));
        return;
    }
    result = nimble_port_init();
    if (result != ESP_OK) {
        ESP_LOGE(tag, "NimBLE initialisation failed: %s", esp_err_to_name(result));
        return;
    }
    ble_hs_cfg.store_status_cb = ble_store_util_status_rr;
    ble_hs_cfg.sm_io_cap = BLE_HS_IO_NO_INPUT_OUTPUT;
    ble_hs_cfg.sm_bonding = 1;
    ble_hs_cfg.sm_sc = 1;
    ble_hs_cfg.sm_our_key_dist = BLE_SM_PAIR_KEY_DIST_ENC;
    ble_hs_cfg.sm_their_key_dist = BLE_SM_PAIR_KEY_DIST_ENC;
    ble_store_config_init();

    if (ble_svc_gap_device_name_set(BLE_DEVICE_NAME) != 0 ||
        ble_gatt_init() != 0) {
        ESP_LOGE(tag, "Could not initialise GATT database");
        return;
    }
    smart_ble_gap_init();
    if (xTaskCreate(simulated_vitals_task, "ble_vitals", 3072, NULL,
                    tskIDLE_PRIORITY + 1, NULL) != pdPASS) {
        ESP_LOGE(tag, "Could not create simulated-vitals task");
        return;
    }
    nimble_port_freertos_init(host_task);
}

bool ble_is_connected(void) { return ble_gap_connection_handle() != BLE_HS_CONN_HANDLE_NONE; }
bool ble_is_encrypted(void) { return ble_gap_is_encrypted(); }
bool ble_notifications_enabled(void)
{
    return ble_is_connected() && ble_gap_is_live_subscribed() && ble_gap_is_stream_enabled();
}

int ble_publish_vitals(const ble_vitals_t *reading)
{
    if (reading == NULL) return BLE_HS_EINVAL;
    if (!ble_is_connected()) return BLE_HS_ENOTCONN;
    if (!ble_notifications_enabled()) return BLE_HS_EAGAIN;
    int result = ble_gatt_publish_reading(reading);
    if (result != 0) ESP_LOGE(tag, "Could not publish telemetry (result=%d)", result);
    return result;
}
