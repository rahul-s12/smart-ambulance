#include <stddef.h>

#include "host/ble_gatt.h"
#include "host/ble_hs.h"
#include "host/ble_hs_mbuf.h"
#include "host/ble_uuid.h"
#include "os/os_mbuf.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "ble.h"

#define UUID_GHSS 0x1840
#define UUID_LIVE_HEALTH_OBSERVATIONS 0x2B8B
#define UUID_GHS_CONTROL_POINT 0x2BF4

static uint16_t live_handle;
static uint16_t control_handle;
static uint8_t segment_counter;
typedef enum { VITAL_TYPE_SPO2, VITAL_TYPE_HEART_RATE, VITAL_TYPE_TEMPERATURE } vital_type_t;
static const ble_uuid16_t service_uuid = BLE_UUID16_INIT(UUID_GHSS);
static const ble_uuid16_t live_uuid = BLE_UUID16_INIT(UUID_LIVE_HEALTH_OBSERVATIONS);
static const ble_uuid16_t control_uuid = BLE_UUID16_INIT(UUID_GHS_CONTROL_POINT);

static int live_access(uint16_t connection_handle, uint16_t attribute_handle,
                       struct ble_gatt_access_ctxt *context, void *argument)
{
    (void)connection_handle; (void)attribute_handle; (void)context; (void)argument;
    return BLE_ATT_ERR_UNLIKELY;
}

static int control_access(uint16_t connection_handle, uint16_t attribute_handle,
                          struct ble_gatt_access_ctxt *context, void *argument)
{
    (void)attribute_handle; (void)argument;
    if (context->op != BLE_GATT_ACCESS_OP_WRITE_CHR || OS_MBUF_PKTLEN(context->om) != 1)
        return BLE_ATT_ERR_UNLIKELY;
    if (!ble_is_encrypted()) return BLE_ATT_ERR_INSUFFICIENT_ENC;
    if (!ble_gap_is_control_subscribed()) return 0xFD;
    uint8_t command;
    if (os_mbuf_copydata(context->om, 0, 1, &command) != 0) return BLE_ATT_ERR_UNLIKELY;
    if (command == 0x01) ble_gap_set_stream_enabled(true);
    else if (command == 0x02) ble_gap_set_stream_enabled(false);
    else return 0x81;
    const uint8_t success = 0x80;
    struct os_mbuf *response = ble_hs_mbuf_from_flat(&success, sizeof(success));
    if (response == NULL) return BLE_ATT_ERR_INSUFFICIENT_RES;
    return ble_gatts_indicate_custom(connection_handle, control_handle, response) == 0 ? 0 : BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def services[] = {
    { .type = BLE_GATT_SVC_TYPE_PRIMARY, .uuid = &service_uuid.u,
      .characteristics = (struct ble_gatt_chr_def[]) {
        { .uuid = &live_uuid.u, .access_cb = live_access, .val_handle = &live_handle,
          .flags = BLE_GATT_CHR_F_NOTIFY },
        { .uuid = &control_uuid.u, .access_cb = control_access, .val_handle = &control_handle,
          .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_ENC | BLE_GATT_CHR_F_INDICATE },
        {0},
      } },
    {0},
};

int ble_gatt_init(void)
{
    ble_svc_gap_init(); ble_svc_gatt_init();
    int result = ble_gatts_count_cfg(services);
    return result == 0 ? ble_gatts_add_svcs(services) : result;
}

bool ble_gatt_is_live_handle(uint16_t handle) { return handle == live_handle; }
bool ble_gatt_is_control_handle(uint16_t handle) { return handle == control_handle; }

static bool encode_numeric(uint8_t frame[16], vital_type_t type, const ble_vitals_t *reading)
{
    uint32_t code; uint16_t unit; int32_t mantissa; int8_t exponent;
    switch (type) {
    case VITAL_TYPE_SPO2:
        if (!(reading->valid_flags & BLE_VITAL_VALID_SPO2)) return false;
        code = 0x00024BB8UL; unit = 0x0220; mantissa = reading->spo2_percent; exponent = 0; break;
    case VITAL_TYPE_HEART_RATE:
        if (!(reading->valid_flags & BLE_VITAL_VALID_HEART_RATE)) return false;
        code = 0x0002481AUL; unit = 0x0F20; mantissa = reading->heart_rate_bpm; exponent = 0; break;
    case VITAL_TYPE_TEMPERATURE:
        if (!(reading->valid_flags & BLE_VITAL_VALID_TEMPERATURE)) return false;
        code = 0x00024A00UL; unit = 0x0172; mantissa = reading->temperature_centi_c; exponent = -2; break;
    default: return false;
    }
    frame[0] = (uint8_t)(0x03U | ((segment_counter++ & 0x3FU) << 2));
    frame[1] = 0x01; frame[2] = 15; frame[3] = 0; frame[4] = 1; frame[5] = 0;
    frame[6] = (uint8_t)code; frame[7] = (uint8_t)(code >> 8); frame[8] = (uint8_t)(code >> 16); frame[9] = (uint8_t)(code >> 24);
    frame[10] = (uint8_t)unit; frame[11] = (uint8_t)(unit >> 8);
    frame[12] = (uint8_t)mantissa; frame[13] = (uint8_t)(mantissa >> 8); frame[14] = (uint8_t)(mantissa >> 16); frame[15] = (uint8_t)exponent;
    return true;
}

int ble_gatt_publish_reading(const ble_vitals_t *reading)
{
    const vital_type_t types[] = {VITAL_TYPE_SPO2, VITAL_TYPE_HEART_RATE, VITAL_TYPE_TEMPERATURE};
    for (size_t index = 0; index < sizeof(types) / sizeof(types[0]); ++index) {
        uint8_t frame[16];
        if (!encode_numeric(frame, types[index], reading)) continue;
        struct os_mbuf *buffer = ble_hs_mbuf_from_flat(frame, sizeof(frame));
        if (buffer == NULL) return BLE_HS_ENOMEM;
        int result = ble_gatts_notify_custom(ble_gap_connection_handle(), live_handle, buffer);
        if (result != 0) return result;
    }
    return 0;
}
