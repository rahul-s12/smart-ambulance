idf_component_register(
    SRCS "ble.c" "ble_gap.c" "ble_gatt.c"
    INCLUDE_DIRS "include"
    PRIV_REQUIRES bt esp_timer nvs_flash
)
