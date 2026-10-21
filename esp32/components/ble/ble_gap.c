#include <string.h>

#include "esp_log.h"
#include "host/ble_gap.h"
#include "host/ble_hs.h"
#include "host/ble_hs_adv.h"
#include "host/ble_hs_id.h"
#include "host/ble_store.h"
#include "host/ble_uuid.h"
#include "services/gap/ble_svc_gap.h"

#include "ble.h"

#define UUID_GHSS 0x1840
static const char *const tag = "smart_ambulance_ble";
static uint8_t address_type;
static uint16_t connection_handle = BLE_HS_CONN_HANDLE_NONE;
static bool encrypted;
static bool live_subscribed;
static bool control_subscribed;
static bool stream_enabled;

static void on_sync(void) { ble_gap_start_advertising(); }

static int gap_event(struct ble_gap_event *event, void *argument)
{
    (void)argument;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            connection_handle = event->connect.conn_handle;
            /*
             * Do not initiate pairing here. Android starts bonding itself when
             * the client accesses the WRITE_ENC control-point characteristic.
             * Starting it from both sides can display two pairing / connection
             * requests for one user action. The encrypted GATT permission keeps
             * telemetry control protected while leaving one owner for bonding.
             */
            ESP_LOGI(tag, "Client connected (handle=%u); waiting for encrypted control access",
                     connection_handle);
        } else {
            ESP_LOGW(tag, "Connection attempt failed (status=%d); advertising again",
                     event->connect.status);
            ble_gap_start_advertising();
        }
        return 0;
    case BLE_GAP_EVENT_DISCONNECT:
        ESP_LOGI(tag, "Client disconnected (reason=%d); advertising again",
                 event->disconnect.reason);
        encrypted = false; live_subscribed = false; control_subscribed = false;
        stream_enabled = false; connection_handle = BLE_HS_CONN_HANDLE_NONE;
        ble_gap_start_advertising();
        return 0;
    case BLE_GAP_EVENT_ENC_CHANGE:
        encrypted = event->enc_change.status == 0;
        ESP_LOGI(tag, "Encryption %s (status=%d)",
                 encrypted ? "enabled" : "failed", event->enc_change.status);
        return 0;
    case BLE_GAP_EVENT_REPEAT_PAIRING: {
        struct ble_gap_conn_desc description;
        if (ble_gap_conn_find(event->repeat_pairing.conn_handle, &description) != 0) {
            return BLE_GAP_REPEAT_PAIRING_IGNORE;
        }
        ESP_LOGW(tag, "Replacing stale bond record before re-pairing");
        (void)ble_store_util_delete_peer(&description.peer_id_addr);
        return BLE_GAP_REPEAT_PAIRING_RETRY;
    }
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (ble_gatt_is_live_handle(event->subscribe.attr_handle)) {
            live_subscribed = event->subscribe.cur_notify;
            ESP_LOGI(tag, "Live observations notifications %s",
                     live_subscribed ? "enabled" : "disabled");
        } else if (ble_gatt_is_control_handle(event->subscribe.attr_handle)) {
            control_subscribed = event->subscribe.cur_indicate;
            ESP_LOGI(tag, "Control-point indications %s",
                     control_subscribed ? "enabled" : "disabled");
        }
        return 0;
    default:
        return 0;
    }
}

void smart_ble_gap_init(void) { ble_hs_cfg.sync_cb = on_sync; }

void ble_gap_start_advertising(void)
{
    struct ble_hs_adv_fields fields = {0};
    struct ble_gap_adv_params parameters = {0};
    ble_uuid16_t service = BLE_UUID16_INIT(UUID_GHSS);
    if (ble_hs_id_infer_auto(0, &address_type) != 0) {
        ESP_LOGE(tag, "Could not determine the BLE address type");
        return;
    }
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.name = (uint8_t *)ble_svc_gap_device_name();
    fields.name_len = strlen((const char *)fields.name);
    fields.name_is_complete = 1;
    fields.uuids16 = &service; fields.num_uuids16 = 1; fields.uuids16_is_complete = 1;
    int result = ble_gap_adv_set_fields(&fields);
    if (result != 0) {
        ESP_LOGE(tag, "Could not set advertisement fields (result=%d)", result);
        return;
    }
    parameters.conn_mode = BLE_GAP_CONN_MODE_UND; parameters.disc_mode = BLE_GAP_DISC_MODE_GEN;
    result = ble_gap_adv_start(address_type, NULL, BLE_HS_FOREVER, &parameters, gap_event, NULL);
    if (result == 0) ESP_LOGI(tag, "Advertising as Smart_Ambulance");
    else ESP_LOGE(tag, "Could not start advertising (result=%d)", result);
}

uint16_t ble_gap_connection_handle(void) { return connection_handle; }
bool ble_gap_is_encrypted(void) { return encrypted; }
bool ble_gap_is_live_subscribed(void) { return live_subscribed; }
bool ble_gap_is_control_subscribed(void) { return control_subscribed; }
bool ble_gap_is_stream_enabled(void) { return stream_enabled && encrypted; }
void ble_gap_set_stream_enabled(bool enabled) { stream_enabled = enabled; }
