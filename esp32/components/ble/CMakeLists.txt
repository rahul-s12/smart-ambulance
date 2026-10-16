idf_component_register(
    SRCS "ble_standard_services.c"
    INCLUDE_DIRS "include"
    PRIV_REQUIRES bt esp_timer nvs_flash
)
