idf_component_register(
    SRCS "main.c" "node_id_store.c" "ble_node.c" "provisioning.c" "mesh_participant.c"
         "ota_apply.c"
    INCLUDE_DIRS "."
    REQUIRES bt nvs_flash driver app_update
    PRIV_REQUIRES espressif__iot_bridge
)
