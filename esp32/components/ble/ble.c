#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "esp_err.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "nvs_flash.h"
    
#include "host/ble_gap.h"
#include "host/ble_gatt.h"
#include "host/ble_hs.h"
#include "host/ble_hs_adv.h"
#include "host/ble_hs_id.h"
#include "host/ble_hs_mbuf.h"
#include "host/ble_store.h"
#include "host/ble_uuid.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "os/os_mbuf.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "ble.h"

static const char *TAG = "smart_ambulance_ble";

#define BLE_DEVICE_NAME "Smart_Ambulance"
#define BLE_PROTOCOL_VERSION 0x01U
#define BLE_MESSAGE_TYPE_MEASUREMENT 0x01U
#define BLE_VITAL_FRAME_SIZE 13U
#define BLE_COMMAND_SEND_TEST_VITALS 0x01U

/* Service UUID: c1a00001-7e1a-4d89-a9e3-6f4b8d250001. */
static const ble_uuid128_t smart_ambulance_service_uuid = BLE_UUID128_INIT(0x01, 0x00, 0x25, 0x8d, 0x4b, 0x6f, 0xe3, 0xa9, 0x89, 0x4d, 0x1a, 0x7e, 0x01, 0x00, 0xa0, 0xc1);

/* Characteristic UUID: c1a00002-7e1a-4d89-a9e3-6f4b8d250001. */
static const ble_uuid128_t device_status_characteristic_uuid = BLE_UUID128_INIT(0x01, 0x00, 0x25, 0x8d, 0x4b, 0x6f, 0xe3, 0xa9, 0x89, 0x4d, 0x1a, 0x7e, 0x02, 0x00, 0xa0, 0xc1);

/* Characteristic UUID: c1a00003-7e1a-4d89-a9e3-6f4b8d250001. */
static const ble_uuid128_t device_command_characteristic_uuid = BLE_UUID128_INIT(0x01, 0x00, 0x25, 0x8d, 0x4b, 0x6f, 0xe3, 0xa9, 0x89, 0x4d, 0x1a, 0x7e, 0x03, 0x00, 0xa0, 0xc1);

/* Characteristic UUID: c1a00004-7e1a-4d89-a9e3-6f4b8d250001. */
static const ble_uuid128_t vital_data_characteristic_uuid = BLE_UUID128_INIT(0x01, 0x00, 0x25, 0x8d, 0x4b, 0x6f, 0xe3, 0xa9, 0x89, 0x4d, 0x1a, 0x7e, 0x04, 0x00, 0xa0, 0xc1);

static uint8_t  own_address_type;
static uint16_t active_connection_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t notification_connection_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t vital_data_value_handle;
static uint16_t next_test_sequence;
static bool connection_encrypted;
static bool     vital_notifications_enabled;

void ble_store_config_init(void);

static void nimble_host_task(void *parameter);
static void on_nimble_sync(void);
static void start_advertising(void);
static int  gap_event(struct ble_gap_event *event, void *argument);
static int  gatt_server_init(void);
static int  device_status_access(uint16_t connection_handle, uint16_t attribute_handle, struct ble_gatt_access_ctxt *context, void *argument);
static int  device_command_access(uint16_t connection_handle, uint16_t attribute_handle, struct ble_gatt_access_ctxt *context, void *argument);
static int  vital_data_access(uint16_t connection_handle, uint16_t attribute_handle, struct ble_gatt_access_ctxt *context, void *argument);
static void encode_vitals_frame(uint8_t frame[BLE_VITAL_FRAME_SIZE], const ble_vitals_t *vitals);
static void write_u16_le(uint8_t *destination, uint16_t value);
static void write_u32_le(uint8_t *destination, uint32_t value);

static const struct ble_gatt_svc_def gatt_services[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &smart_ambulance_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &device_status_characteristic_uuid.u,
                .access_cb = device_status_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_READ_ENC,
            },
            {
                .uuid = &device_command_characteristic_uuid.u,
                .access_cb = device_command_access,
                .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_ENC,
            },
            {
                .uuid = &vital_data_characteristic_uuid.u,
                .access_cb = vital_data_access,
                .val_handle = &vital_data_value_handle,
                .flags = BLE_GATT_CHR_F_NOTIFY,
            },
            { 0 },
        },
    },
    { 0 },
};

void ble_init(void) {
    esp_err_t error = nvs_flash_init();
    if (error == ESP_ERR_NVS_NO_FREE_PAGES || error == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        error = nvs_flash_init();
    }
    ESP_ERROR_CHECK(error);

    error = nimble_port_init();
    if (error != ESP_OK) {
        ESP_LOGE(TAG, "NimBLE initialisation failed: %s", esp_err_to_name(error));
        return;
    }

    ble_hs_cfg.sync_cb = on_nimble_sync;
    ble_hs_cfg.store_status_cb = ble_store_util_status_rr;
    ble_hs_cfg.sm_io_cap = BLE_HS_IO_NO_INPUT_OUTPUT;
    ble_hs_cfg.sm_bonding = 1;
    ble_hs_cfg.sm_mitm = 0;
    ble_hs_cfg.sm_sc = 1;
    ble_hs_cfg.sm_our_key_dist = BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID;
    ble_hs_cfg.sm_their_key_dist = BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID;

    ble_store_config_init();

    const int device_name_result = ble_svc_gap_device_name_set(BLE_DEVICE_NAME);
    if (device_name_result != 0) {
        ESP_LOGE(TAG, "Could not set the BLE device name: %d", device_name_result);
        return;
    }

    const int return_code = gatt_server_init();
    if (return_code != 0) {
        ESP_LOGE(TAG, "GATT registration failed: %d", return_code);
        return;
    }

    nimble_port_freertos_init(nimble_host_task);
}

bool ble_is_connected(void) {
    return active_connection_handle != BLE_HS_CONN_HANDLE_NONE;
}

bool ble_is_encrypted(void) {
    return connection_encrypted;
}

bool ble_notifications_enabled(void) {
    return vital_notifications_enabled && ble_is_connected();
}

int ble_publish_vitals(const ble_vitals_t *vitals) {
    if (vitals == NULL) {
        return BLE_HS_EINVAL;
    }

    if (!ble_is_encrypted() || !ble_notifications_enabled() ||
        notification_connection_handle != active_connection_handle) {
        ESP_LOGW(TAG, "Cannot publish vitals: encrypted, subscribed phone required");
        return ble_is_connected() ? BLE_HS_EAUTHEN : BLE_HS_ENOTCONN;
    }

    uint8_t frame[BLE_VITAL_FRAME_SIZE];
    encode_vitals_frame(frame, vitals);

    struct os_mbuf *message_buffer = ble_hs_mbuf_from_flat(frame, sizeof(frame));
    if (message_buffer == NULL) {
        ESP_LOGE(TAG, "Could not allocate a vital notification buffer");
        return BLE_HS_ENOMEM;
    }

    const int return_code = ble_gatts_notify_custom(notification_connection_handle, vital_data_value_handle, message_buffer);
    if (return_code != 0) {
        ESP_LOGE(TAG, "Could not queue vital notification: %d", return_code);
        return return_code;
    }

    ESP_LOGI(TAG, "Published vital frame: sequence=%u", vitals->sequence);
    return 0;
}

static void on_nimble_sync(void) {
    ESP_LOGI(TAG, "NimBLE synchronised with the controller");
    start_advertising();
}

static void nimble_host_task(void *parameter) {
    (void)parameter;
    nimble_port_run();
    nimble_port_freertos_deinit();
}

static void start_advertising(void) {
    struct ble_hs_adv_fields fields;
    struct ble_gap_adv_params advertising_parameters;
    int return_code = ble_hs_id_infer_auto(0, &own_address_type);

    if (return_code != 0) {
        ESP_LOGE(TAG, "Could not infer BLE address type: %d", return_code);
        return;
    }

    memset(&fields, 0, sizeof(fields));
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.name = (uint8_t *)ble_svc_gap_device_name();
    fields.name_len = strlen(BLE_DEVICE_NAME);
    fields.name_is_complete = 1;

    return_code = ble_gap_adv_set_fields(&fields);
    if (return_code != 0) {
        ESP_LOGE(TAG, "Could not configure BLE advertising data: %d", return_code);
        return;
    }

    memset(&advertising_parameters, 0, sizeof(advertising_parameters));
    advertising_parameters.conn_mode = BLE_GAP_CONN_MODE_UND;
    advertising_parameters.disc_mode = BLE_GAP_DISC_MODE_GEN;

    return_code = ble_gap_adv_start(own_address_type, NULL, BLE_HS_FOREVER, &advertising_parameters, gap_event, NULL);
    if (return_code != 0) {
        ESP_LOGE(TAG, "Could not start BLE advertising: %d", return_code);
        return;
    }

    ESP_LOGI(TAG, "Advertising as %s", BLE_DEVICE_NAME);
}

static int gap_event(struct ble_gap_event *event, void *argument) {
    (void)argument;

    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            active_connection_handle = event->connect.conn_handle;
            ESP_LOGI(TAG, "Phone connected: handle=%d", active_connection_handle);
            const int return_code = ble_gap_security_initiate(active_connection_handle);
            if (return_code != 0) {
                ESP_LOGE(TAG, "Could not start pairing: %d", return_code);
            }
        } else {
            ESP_LOGW(TAG, "BLE connection failed: status=%d", event->connect.status);
            start_advertising();
        }
        return 0;

    case BLE_GAP_EVENT_DISCONNECT:
        ESP_LOGI(TAG, "Phone disconnected: reason=%d", event->disconnect.reason);
        if (notification_connection_handle == event->disconnect.conn.conn_handle) {
            vital_notifications_enabled = false;
            notification_connection_handle = BLE_HS_CONN_HANDLE_NONE;
        }
        connection_encrypted = false;
        active_connection_handle = BLE_HS_CONN_HANDLE_NONE;
        start_advertising();
        return 0;

    case BLE_GAP_EVENT_ENC_CHANGE:
        connection_encrypted = event->enc_change.status == 0;
        ESP_LOGI(TAG, "Link encryption %s: status=%d",
                 connection_encrypted ? "enabled" : "failed",
                 event->enc_change.status);
        return 0;

    case BLE_GAP_EVENT_REPEAT_PAIRING: {
        struct ble_gap_conn_desc connection_description;
        const int return_code = ble_gap_conn_find(event->repeat_pairing.conn_handle,
                                                  &connection_description);
        if (return_code != 0) {
            ESP_LOGE(TAG, "Could not find peer for repeat pairing: %d", return_code);
            return BLE_GAP_REPEAT_PAIRING_IGNORE;
        }

        const int delete_result = ble_store_util_delete_peer(&connection_description.peer_id_addr);
        if (delete_result != 0) {
            ESP_LOGE(TAG, "Could not delete the previous bond: %d", delete_result);
            return BLE_GAP_REPEAT_PAIRING_IGNORE;
        }

        ESP_LOGW(TAG, "Replacing the existing bond for the connected phone");
        return BLE_GAP_REPEAT_PAIRING_RETRY;
    }

    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == vital_data_value_handle) {
            vital_notifications_enabled = event->subscribe.cur_notify;
            notification_connection_handle = event->subscribe.cur_notify ? event->subscribe.conn_handle : BLE_HS_CONN_HANDLE_NONE;
            ESP_LOGI(TAG, "Vital notifications %s", event->subscribe.cur_notify ? "enabled" : "disabled");
        }
        return 0;

    default: return 0;
    }
}

static int gatt_server_init(void) {
    ble_svc_gap_init();
    ble_svc_gatt_init();

    int return_code = ble_gatts_count_cfg(gatt_services);
    if (return_code != 0) {
        return return_code;
    }

    return_code = ble_gatts_add_svcs(gatt_services);
    if (return_code != 0) {
        return return_code;
    }

    /* ESP-IDF starts the NimBLE GATT database when the host task starts. */
    ESP_LOGI(TAG, "GATT services registered; vital characteristic handle=%d",
             vital_data_value_handle);
    return 0;
}

static int device_status_access(uint16_t connection_handle, uint16_t attribute_handle, struct ble_gatt_access_ctxt *context, void *argument) {
    (void)connection_handle;
    (void)attribute_handle;
    (void)argument;

    static const char status[] = "READY";
    if (context->op != BLE_GATT_ACCESS_OP_READ_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    return os_mbuf_append(context->om, status, sizeof(status) - 1) == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}

static int device_command_access(uint16_t connection_handle, uint16_t attribute_handle, struct ble_gatt_access_ctxt *context, void *argument) {
    (void)connection_handle;
    (void)attribute_handle;
    (void)argument;

    if (context->op != BLE_GATT_ACCESS_OP_WRITE_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    if (OS_MBUF_PKTLEN(context->om) != 1) {
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }

    uint8_t command;
    if (os_mbuf_copydata(context->om, 0, sizeof(command), &command) != 0) {
        return BLE_ATT_ERR_UNLIKELY;
    }

    if (command != BLE_COMMAND_SEND_TEST_VITALS) {
        ESP_LOGW(TAG, "Unsupported device command: 0x%02X", command);
        return BLE_ATT_ERR_UNLIKELY;
    }

    const ble_vitals_t test_vitals = {
        .timestamp_ms = (uint32_t)(esp_timer_get_time() / 1000),
        .sequence = next_test_sequence++,
        .temperature_centi_c = 3675,
        .heart_rate_bpm = 72,
        .spo2_percent = 98,
        .valid_flags = BLE_VITAL_VALID_HEART_RATE | BLE_VITAL_VALID_SPO2 | BLE_VITAL_VALID_TEMPERATURE,
    };

    return ble_publish_vitals(&test_vitals) == 0 ? 0 : BLE_ATT_ERR_UNLIKELY;
}

static int vital_data_access(uint16_t connection_handle, uint16_t attribute_handle, struct ble_gatt_access_ctxt *context, void *argument){
    (void)connection_handle;
    (void)attribute_handle;
    (void)context;
    (void)argument;
    return BLE_ATT_ERR_UNLIKELY;
}

static void encode_vitals_frame(uint8_t frame[BLE_VITAL_FRAME_SIZE], const ble_vitals_t *vitals) {
    frame[0] = BLE_PROTOCOL_VERSION;
    frame[1] = BLE_MESSAGE_TYPE_MEASUREMENT;
    write_u16_le(&frame[2], vitals->sequence);
    write_u32_le(&frame[4], vitals->timestamp_ms);
    frame[8] = vitals->heart_rate_bpm;
    frame[9] = vitals->spo2_percent;
    write_u16_le(&frame[10], (uint16_t)vitals->temperature_centi_c);
    frame[12] = vitals->valid_flags;
}

static void write_u16_le(uint8_t *destination, uint16_t value) {
    destination[0] = (uint8_t)(value & 0xFFU);
    destination[1] = (uint8_t)((value >> 8) & 0xFFU);
}

static void write_u32_le(uint8_t *destination, uint32_t value) {
    destination[0] = (uint8_t)(value & 0xFFU);
    destination[1] = (uint8_t)((value >> 8) & 0xFFU);
    destination[2] = (uint8_t)((value >> 16) & 0xFFU);
    destination[3] = (uint8_t)((value >> 24) & 0xFFU);
}
