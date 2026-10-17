#if 0 /* Replaced by the Generic Health Sensor implementation below. */
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "esp_err.h"
#include "esp_log.h"
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

/* Bluetooth SIG adopted services and characteristics. */
#define BLE_SVC_PULSE_OXIMETER_UUID16       0x1822
#define BLE_CHR_PLX_CONTINUOUS_MEAS_UUID16  0x2A5F
#define BLE_CHR_PLX_FEATURES_UUID16         0x2A60
#define BLE_SVC_HEALTH_THERMOMETER_UUID16   0x1809
#define BLE_CHR_TEMP_MEASUREMENT_UUID16     0x2A1C
#define BLE_CHR_TEMP_TYPE_UUID16            0x2A1D
#define BLE_CHR_INTERMEDIATE_TEMP_UUID16    0x2A1E

static uint8_t own_address_type;
static uint16_t active_connection_handle = BLE_HS_CONN_HANDLE_NONE;
static bool connection_encrypted;
static bool plx_notifications_enabled;
static bool temperature_notifications_enabled;
static bool temperature_indications_enabled;
static uint16_t plx_continuous_measurement_handle;
static uint16_t temperature_measurement_handle;
static uint16_t intermediate_temperature_handle;

void ble_store_config_init(void);

static void nimble_host_task(void *parameter);
static void on_nimble_sync(void);
static void start_advertising(void);
static int gap_event(struct ble_gap_event *event, void *argument);
static int gatt_server_init(void);
static int plx_features_access(uint16_t connection_handle, uint16_t attribute_handle,
                               struct ble_gatt_access_ctxt *context, void *argument);
static int temperature_type_access(uint16_t connection_handle, uint16_t attribute_handle,
                                   struct ble_gatt_access_ctxt *context, void *argument);
static int measurement_access(uint16_t connection_handle, uint16_t attribute_handle,
                              struct ble_gatt_access_ctxt *context, void *argument);
static uint16_t encode_sfloat(int32_t value);
static void encode_temperature(uint8_t frame[5], int16_t centi_c);

static const ble_uuid16_t plx_service_uuid = BLE_UUID16_INIT(BLE_SVC_PULSE_OXIMETER_UUID16);
static const ble_uuid16_t plx_continuous_uuid = BLE_UUID16_INIT(BLE_CHR_PLX_CONTINUOUS_MEAS_UUID16);
static const ble_uuid16_t plx_features_uuid = BLE_UUID16_INIT(BLE_CHR_PLX_FEATURES_UUID16);
static const ble_uuid16_t thermometer_service_uuid = BLE_UUID16_INIT(BLE_SVC_HEALTH_THERMOMETER_UUID16);
static const ble_uuid16_t temperature_measurement_uuid = BLE_UUID16_INIT(BLE_CHR_TEMP_MEASUREMENT_UUID16);
static const ble_uuid16_t temperature_type_uuid = BLE_UUID16_INIT(BLE_CHR_TEMP_TYPE_UUID16);
static const ble_uuid16_t intermediate_temperature_uuid = BLE_UUID16_INIT(BLE_CHR_INTERMEDIATE_TEMP_UUID16);

static const struct ble_gatt_svc_def gatt_services[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &plx_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &plx_continuous_uuid.u,
                .access_cb = measurement_access,
                .val_handle = &plx_continuous_measurement_handle,
                .flags = BLE_GATT_CHR_F_NOTIFY,
            },
            {
                .uuid = &plx_features_uuid.u,
                .access_cb = plx_features_access,
                .flags = BLE_GATT_CHR_F_READ,
            },
            { 0 },
        },
    },
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &thermometer_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &temperature_measurement_uuid.u,
                .access_cb = measurement_access,
                .val_handle = &temperature_measurement_handle,
                .flags = BLE_GATT_CHR_F_INDICATE,
            },
            {
                .uuid = &temperature_type_uuid.u,
                .access_cb = temperature_type_access,
                .flags = BLE_GATT_CHR_F_READ,
            },
            {
                .uuid = &intermediate_temperature_uuid.u,
                .access_cb = measurement_access,
                .val_handle = &intermediate_temperature_handle,
                .flags = BLE_GATT_CHR_F_NOTIFY,
            },
            { 0 },
        },
    },
    { 0 },
};

void ble_init(void)
{
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
    ble_hs_cfg.sm_sc = 1;
    /* Exchange encryption keys for bonding; identity keys are only needed for address privacy. */
    ble_hs_cfg.sm_our_key_dist = BLE_SM_PAIR_KEY_DIST_ENC;
    ble_hs_cfg.sm_their_key_dist = BLE_SM_PAIR_KEY_DIST_ENC;
    ble_store_config_init();

    int result = ble_svc_gap_device_name_set(BLE_DEVICE_NAME);
    if (result == 0) {
        result = gatt_server_init();
    }
    if (result != 0) {
        ESP_LOGE(TAG, "BLE initialisation failed: %d", result);
        return;
    }
    nimble_port_freertos_init(nimble_host_task);
}

bool ble_is_connected(void)
{
    return active_connection_handle != BLE_HS_CONN_HANDLE_NONE;
}

bool ble_is_encrypted(void)
{
    return connection_encrypted;
}

bool ble_notifications_enabled(void)
{
    return ble_is_connected() && (plx_notifications_enabled || temperature_notifications_enabled ||
                                  temperature_indications_enabled);
}

int ble_publish_vitals(const ble_vitals_t *vitals)
{
    if (vitals == NULL) {
        return BLE_HS_EINVAL;
    }
    if (!ble_is_connected()) {
        return BLE_HS_ENOTCONN;
    }
    if (!connection_encrypted) {
        return BLE_HS_EAUTHEN;
    }

    int result = 0;
    if (plx_notifications_enabled &&
        (vitals->valid_flags & (BLE_VITAL_VALID_HEART_RATE | BLE_VITAL_VALID_SPO2)) != 0U) {
        /* Flags=0; mandatory normal SpO2 and pulse-rate IEEE-11073 SFLOAT values. */
        uint8_t frame[5] = { 0 };
        const uint16_t spo2 = encode_sfloat(vitals->spo2_percent);
        const uint16_t pulse = encode_sfloat(vitals->heart_rate_bpm);
        frame[1] = (uint8_t)spo2;
        frame[2] = (uint8_t)(spo2 >> 8);
        frame[3] = (uint8_t)pulse;
        frame[4] = (uint8_t)(pulse >> 8);
        struct os_mbuf *buffer = ble_hs_mbuf_from_flat(frame, sizeof(frame));
        if (buffer == NULL) {
            return BLE_HS_ENOMEM;
        }
        result = ble_gatts_notify_custom(active_connection_handle,
                                         plx_continuous_measurement_handle, buffer);
        if (result != 0) {
            return result;
        }
    }

    if ((vitals->valid_flags & BLE_VITAL_VALID_TEMPERATURE) == 0U) {
        return result;
    }

    uint8_t temperature_frame[5];
    encode_temperature(temperature_frame, vitals->temperature_centi_c);
    if (temperature_notifications_enabled) {
        struct os_mbuf *buffer = ble_hs_mbuf_from_flat(temperature_frame, sizeof(temperature_frame));
        if (buffer == NULL) {
            return BLE_HS_ENOMEM;
        }
        result = ble_gatts_notify_custom(active_connection_handle,
                                         intermediate_temperature_handle, buffer);
        if (result != 0) {
            return result;
        }
    }
    if (temperature_indications_enabled) {
        struct os_mbuf *buffer = ble_hs_mbuf_from_flat(temperature_frame, sizeof(temperature_frame));
        if (buffer == NULL) {
            return BLE_HS_ENOMEM;
        }
        result = ble_gatts_indicate_custom(active_connection_handle,
                                           temperature_measurement_handle, buffer);
    }
    return result;
}

static void on_nimble_sync(void)
{
    ESP_LOGI(TAG, "Standard GATT database active: PLX=%d, temperature=%d",
             plx_continuous_measurement_handle, intermediate_temperature_handle);
    start_advertising();
}

static void nimble_host_task(void *parameter)
{
    (void)parameter;
    nimble_port_run();
    nimble_port_freertos_deinit();
}

static void start_advertising(void)
{
    struct ble_hs_adv_fields fields = { 0 };
    struct ble_gap_adv_params parameters = { 0 };
    int result = ble_hs_id_infer_auto(0, &own_address_type);
    if (result != 0) {
        ESP_LOGE(TAG, "Could not infer BLE address type: %d", result);
        return;
    }
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.name = (uint8_t *)ble_svc_gap_device_name();
    fields.name_len = strlen(BLE_DEVICE_NAME);
    fields.name_is_complete = 1;
    result = ble_gap_adv_set_fields(&fields);
    if (result != 0) {
        ESP_LOGE(TAG, "Could not configure advertising data: %d", result);
        return;
    }
    parameters.conn_mode = BLE_GAP_CONN_MODE_UND;
    parameters.disc_mode = BLE_GAP_DISC_MODE_GEN;
    result = ble_gap_adv_start(own_address_type, NULL, BLE_HS_FOREVER, &parameters,
                               gap_event, NULL);
    if (result != 0) {
        ESP_LOGE(TAG, "Could not start advertising: %d", result);
    }
}

static int gap_event(struct ble_gap_event *event, void *argument)
{
    (void)argument;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            active_connection_handle = event->connect.conn_handle;
            (void)ble_gap_security_initiate(active_connection_handle);
        } else {
            start_advertising();
        }
        return 0;
    case BLE_GAP_EVENT_DISCONNECT:
        connection_encrypted = false;
        plx_notifications_enabled = false;
        temperature_notifications_enabled = false;
        temperature_indications_enabled = false;
        active_connection_handle = BLE_HS_CONN_HANDLE_NONE;
        start_advertising();
        return 0;
    case BLE_GAP_EVENT_ENC_CHANGE:
        connection_encrypted = event->enc_change.status == 0;
        return 0;
    case BLE_GAP_EVENT_REPEAT_PAIRING: {
        struct ble_gap_conn_desc description;
        if (ble_gap_conn_find(event->repeat_pairing.conn_handle, &description) != 0) {
            return BLE_GAP_REPEAT_PAIRING_IGNORE;
        }
        (void)ble_store_util_delete_peer(&description.peer_id_addr);
        return BLE_GAP_REPEAT_PAIRING_RETRY;
    }
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == plx_continuous_measurement_handle) {
            plx_notifications_enabled = event->subscribe.cur_notify;
        } else if (event->subscribe.attr_handle == intermediate_temperature_handle) {
            temperature_notifications_enabled = event->subscribe.cur_notify;
        } else if (event->subscribe.attr_handle == temperature_measurement_handle) {
            temperature_indications_enabled = event->subscribe.cur_indicate;
        }
        return 0;
    default:
        return 0;
    }
}

static int gatt_server_init(void)
{
    ble_svc_gap_init();
    ble_svc_gatt_init();
    int result = ble_gatts_count_cfg(gatt_services);
    return result == 0 ? ble_gatts_add_svcs(gatt_services) : result;
}

static int plx_features_access(uint16_t connection_handle, uint16_t attribute_handle,
                               struct ble_gatt_access_ctxt *context, void *argument)
{
    (void)connection_handle;
    (void)attribute_handle;
    (void)argument;
    if (context->op != BLE_GATT_ACCESS_OP_READ_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }
    static const uint8_t features[2] = { 0, 0 };
    return os_mbuf_append(context->om, features, sizeof(features)) == 0 ?
               0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}

static int temperature_type_access(uint16_t connection_handle, uint16_t attribute_handle,
                                   struct ble_gatt_access_ctxt *context, void *argument)
{
    (void)connection_handle;
    (void)attribute_handle;
    (void)argument;
    if (context->op != BLE_GATT_ACCESS_OP_READ_CHR) {
        return BLE_ATT_ERR_UNLIKELY;
    }
    static const uint8_t body_temperature = 0x02;
    return os_mbuf_append(context->om, &body_temperature, sizeof(body_temperature)) == 0 ?
               0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}

/* Measurements are sent asynchronously as notifications or indications. */
static int measurement_access(uint16_t connection_handle, uint16_t attribute_handle,
                              struct ble_gatt_access_ctxt *context, void *argument)
{
    (void)connection_handle;
    (void)attribute_handle;
    (void)context;
    (void)argument;
    return BLE_ATT_ERR_UNLIKELY;
}

static uint16_t encode_sfloat(int32_t value)
{
    if (value > 2047) {
        value = 2047;
    } else if (value < -2048) {
        value = -2048;
    }
    return (uint16_t)(value & 0x0FFF);
}

static void encode_temperature(uint8_t frame[5], int16_t centi_c)
{
    const uint32_t mantissa = (uint32_t)centi_c & 0x00FFFFFFU;
    frame[0] = 0x00;
    frame[1] = (uint8_t)mantissa;
    frame[2] = (uint8_t)(mantissa >> 8);
    frame[3] = (uint8_t)(mantissa >> 16);
    frame[4] = 0xFE; /* IEEE-11073 FLOAT exponent -2. */
}
#endif

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "esp_err.h"
#include "esp_log.h"
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

/* Standard BLE-SIG Generic Health Sensor Service (GHSS), UUID 0x1840. */
#define BLE_DEVICE_NAME "Smart_Ambulance"
#define UUID_GHSS 0x1840
#define UUID_LIVE_HEALTH_OBSERVATIONS 0x2B8B
#define UUID_GHS_CONTROL_POINT 0x2BF4

/* IEEE 11073 MDC codes used by the simulated vital stream. */
#define MDC_SPO2 0x00024BB8UL
#define MDC_PULSE_RATE 0x0002481AUL
#define MDC_BODY_TEMPERATURE 0x00024A00UL
#define UNIT_PERCENT 0x0220U
#define UNIT_BEATS_PER_MINUTE 0x0F20U
#define UNIT_DEGREES_C 0x0172U

static const char *const ghss_tag = "smart_ambulance_ble";
static uint8_t ghss_address_type;
static uint16_t ghss_connection_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t ghss_live_handle;
static uint16_t ghss_control_handle;
static bool ghss_encrypted;
static bool ghss_live_subscribed;
static bool ghss_control_subscribed;
static bool ghss_stream_started;
static uint8_t ghss_segment_counter;

void ble_store_config_init(void);

static void ghss_host_task(void *parameter);
static void ghss_on_sync(void);
static void ghss_start_advertising(void);
static int ghss_gap_event(struct ble_gap_event *event, void *argument);
static int ghss_init_database(void);
static int ghss_live_access(uint16_t connection_handle, uint16_t attribute_handle,
                            struct ble_gatt_access_ctxt *context, void *argument);
static int ghss_control_access(uint16_t connection_handle, uint16_t attribute_handle,
                               struct ble_gatt_access_ctxt *context, void *argument);
static int ghss_send_numeric(uint32_t type, uint16_t unit, int32_t mantissa, int8_t exponent);
static void ghss_put_u16(uint8_t *destination, uint16_t value);
static void ghss_put_u32(uint8_t *destination, uint32_t value);

static const ble_uuid16_t ghss_uuid = BLE_UUID16_INIT(UUID_GHSS);
static const ble_uuid16_t ghss_live_uuid = BLE_UUID16_INIT(UUID_LIVE_HEALTH_OBSERVATIONS);
static const ble_uuid16_t ghss_control_uuid = BLE_UUID16_INIT(UUID_GHS_CONTROL_POINT);

static const struct ble_gatt_svc_def ghss_services[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &ghss_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            { .uuid = &ghss_live_uuid.u, .access_cb = ghss_live_access,
              .val_handle = &ghss_live_handle, .flags = BLE_GATT_CHR_F_NOTIFY },
            { .uuid = &ghss_control_uuid.u, .access_cb = ghss_control_access,
              .val_handle = &ghss_control_handle,
              .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_INDICATE },
            { 0 },
        },
    },
    { 0 },
};

void ble_init(void)
{
    esp_err_t error = nvs_flash_init();
    if (error == ESP_ERR_NVS_NO_FREE_PAGES || error == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        error = nvs_flash_init();
    }
    ESP_ERROR_CHECK(error);
    error = nimble_port_init();
    if (error != ESP_OK) {
        ESP_LOGE(ghss_tag, "NimBLE initialisation failed: %s", esp_err_to_name(error));
        return;
    }
    ble_hs_cfg.sync_cb = ghss_on_sync;
    ble_hs_cfg.store_status_cb = ble_store_util_status_rr;
    ble_hs_cfg.sm_io_cap = BLE_HS_IO_NO_INPUT_OUTPUT;
    ble_hs_cfg.sm_bonding = 1;
    ble_hs_cfg.sm_sc = 1;
    /* Retain encrypted bonding; do not request optional address-privacy identity keys. */
    ble_hs_cfg.sm_our_key_dist = BLE_SM_PAIR_KEY_DIST_ENC;
    ble_hs_cfg.sm_their_key_dist = BLE_SM_PAIR_KEY_DIST_ENC;
    ble_store_config_init();

    int result = ble_svc_gap_device_name_set(BLE_DEVICE_NAME);
    if (result == 0) {
        result = ghss_init_database();
    }
    if (result != 0) {
        ESP_LOGE(ghss_tag, "BLE initialisation failed: %d", result);
        return;
    }
    nimble_port_freertos_init(ghss_host_task);
}

bool ble_is_connected(void) { return ghss_connection_handle != BLE_HS_CONN_HANDLE_NONE; }
bool ble_is_encrypted(void) { return ghss_encrypted; }
bool ble_notifications_enabled(void)
{
    return ble_is_connected() && ghss_live_subscribed && ghss_stream_started;
}

int ble_publish_vitals(const ble_vitals_t *vitals)
{
    if (vitals == NULL) return BLE_HS_EINVAL;
    if (!ble_is_connected()) return BLE_HS_ENOTCONN;
    if (!ghss_encrypted) return BLE_HS_EAUTHEN;
    if (!ghss_live_subscribed || !ghss_stream_started) return BLE_HS_EAGAIN;

    int result = 0;
    if ((vitals->valid_flags & BLE_VITAL_VALID_SPO2) != 0U) {
        result = ghss_send_numeric(MDC_SPO2, UNIT_PERCENT, vitals->spo2_percent, 0);
    }
    if (result == 0 && (vitals->valid_flags & BLE_VITAL_VALID_HEART_RATE) != 0U) {
        result = ghss_send_numeric(MDC_PULSE_RATE, UNIT_BEATS_PER_MINUTE,
                                   vitals->heart_rate_bpm, 0);
    }
    if (result == 0 && (vitals->valid_flags & BLE_VITAL_VALID_TEMPERATURE) != 0U) {
        result = ghss_send_numeric(MDC_BODY_TEMPERATURE, UNIT_DEGREES_C,
                                   vitals->temperature_centi_c, -2);
    }
    return result;
}

static void ghss_on_sync(void)
{
    ESP_LOGI(ghss_tag, "Standard GATT database active: GHSS=0x1840 Live=0x%04X",
             ghss_live_handle);
    ghss_start_advertising();
}

static void ghss_host_task(void *parameter)
{
    (void)parameter;
    nimble_port_run();
    nimble_port_freertos_deinit();
}

static void ghss_start_advertising(void)
{
    struct ble_hs_adv_fields fields = { 0 };
    struct ble_gap_adv_params parameters = { 0 };
    ble_uuid16_t advertised_service = BLE_UUID16_INIT(UUID_GHSS);
    int result = ble_hs_id_infer_auto(0, &ghss_address_type);
    if (result != 0) return;
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.name = (uint8_t *)ble_svc_gap_device_name();
    fields.name_len = strlen(BLE_DEVICE_NAME);
    fields.name_is_complete = 1;
    fields.uuids16 = &advertised_service;
    fields.num_uuids16 = 1;
    fields.uuids16_is_complete = 1;
    result = ble_gap_adv_set_fields(&fields);
    if (result == 0) {
        parameters.conn_mode = BLE_GAP_CONN_MODE_UND;
        parameters.disc_mode = BLE_GAP_DISC_MODE_GEN;
        result = ble_gap_adv_start(ghss_address_type, NULL, BLE_HS_FOREVER, &parameters,
                                   ghss_gap_event, NULL);
    }
    if (result != 0) ESP_LOGE(ghss_tag, "Could not start advertising: %d", result);
}

static int ghss_gap_event(struct ble_gap_event *event, void *argument)
{
    (void)argument;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            ghss_connection_handle = event->connect.conn_handle;
            (void)ble_gap_security_initiate(ghss_connection_handle);
        } else ghss_start_advertising();
        return 0;
    case BLE_GAP_EVENT_DISCONNECT:
        ghss_encrypted = false;
        ghss_live_subscribed = false;
        ghss_control_subscribed = false;
        ghss_stream_started = false;
        ghss_connection_handle = BLE_HS_CONN_HANDLE_NONE;
        ghss_start_advertising();
        return 0;
    case BLE_GAP_EVENT_ENC_CHANGE:
        ghss_encrypted = event->enc_change.status == 0;
        return 0;
    case BLE_GAP_EVENT_REPEAT_PAIRING: {
        /* A phone requesting pairing again has a stale or missing LTK. Replace only that peer record. */
        struct ble_gap_conn_desc description;
        if (ble_gap_conn_find(event->repeat_pairing.conn_handle, &description) != 0) {
            return BLE_GAP_REPEAT_PAIRING_IGNORE;
        }
        ESP_LOGW(ghss_tag, "Replacing stale bond record before re-pairing");
        (void)ble_store_util_delete_peer(&description.peer_id_addr);
        return BLE_GAP_REPEAT_PAIRING_RETRY;
    }
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == ghss_live_handle)
            ghss_live_subscribed = event->subscribe.cur_notify;
        else if (event->subscribe.attr_handle == ghss_control_handle)
            ghss_control_subscribed = event->subscribe.cur_indicate;
        return 0;
    default: return 0;
    }
}

static int ghss_init_database(void)
{
    ble_svc_gap_init();
    ble_svc_gatt_init();
    int result = ble_gatts_count_cfg(ghss_services);
    return result == 0 ? ble_gatts_add_svcs(ghss_services) : result;
}

static int ghss_live_access(uint16_t connection_handle, uint16_t attribute_handle,
                            struct ble_gatt_access_ctxt *context, void *argument)
{
    (void)connection_handle; (void)attribute_handle; (void)context; (void)argument;
    return BLE_ATT_ERR_UNLIKELY;
}

static int ghss_control_access(uint16_t connection_handle, uint16_t attribute_handle,
                               struct ble_gatt_access_ctxt *context, void *argument)
{
    (void)attribute_handle; (void)argument;
    if (context->op != BLE_GATT_ACCESS_OP_WRITE_CHR || OS_MBUF_PKTLEN(context->om) != 1)
        return BLE_ATT_ERR_UNLIKELY;
    if (!ghss_control_subscribed) return 0xFD;
    uint8_t command;
    if (os_mbuf_copydata(context->om, 0, 1, &command) != 0) return BLE_ATT_ERR_UNLIKELY;
    if (command == 0x01) ghss_stream_started = true;
    else if (command == 0x02) ghss_stream_started = false;
    else return 0x81;

    const uint8_t success = 0x80;
    struct os_mbuf *response = ble_hs_mbuf_from_flat(&success, sizeof(success));
    if (response == NULL) return BLE_ATT_ERR_INSUFFICIENT_RES;
    return ble_gatts_indicate_custom(connection_handle, ghss_control_handle, response) == 0 ?
        0 : BLE_ATT_ERR_UNLIKELY;
}

static int ghss_send_numeric(uint32_t type, uint16_t unit, int32_t mantissa, int8_t exponent)
{
    /* Segmentation header + complete Numeric Observation: 16 bytes. */
    uint8_t frame[16] = { 0 };
    frame[0] = (uint8_t)(0x03U | ((ghss_segment_counter++ & 0x3FU) << 2));
    frame[1] = 0x01; /* ACOM Numeric observation. */
    ghss_put_u16(&frame[2], 15);
    ghss_put_u16(&frame[4], 0x0001); /* Observation Type included. */
    ghss_put_u32(&frame[6], type);
    ghss_put_u16(&frame[10], unit);
    frame[12] = (uint8_t)mantissa;
    frame[13] = (uint8_t)(mantissa >> 8);
    frame[14] = (uint8_t)(mantissa >> 16);
    frame[15] = (uint8_t)exponent; /* IEEE 11073 FLOAT. */
    struct os_mbuf *buffer = ble_hs_mbuf_from_flat(frame, sizeof(frame));
    if (buffer == NULL) return BLE_HS_ENOMEM;
    return ble_gatts_notify_custom(ghss_connection_handle, ghss_live_handle, buffer);
}

static void ghss_put_u16(uint8_t *destination, uint16_t value)
{
    destination[0] = (uint8_t)value;
    destination[1] = (uint8_t)(value >> 8);
}

static void ghss_put_u32(uint8_t *destination, uint32_t value)
{
    destination[0] = (uint8_t)value;
    destination[1] = (uint8_t)(value >> 8);
    destination[2] = (uint8_t)(value >> 16);
    destination[3] = (uint8_t)(value >> 24);
}
