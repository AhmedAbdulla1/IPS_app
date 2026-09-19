idf_component_register(
    SRCS "mesh_root_main.c" "health_table.c" "serial_output.c" "mesh_bridge.c"
         "serial_input.c" "ota_receiver.c" "ota_relay.c"
    INCLUDE_DIRS "."
    REQUIRES driver app_update mbedtls nvs_flash
    PRIV_REQUIRES espressif__iot_bridge espressif__mesh_lite
)
