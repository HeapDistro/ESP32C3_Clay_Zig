set(srcs "pretty_effect.c"
    "spi_master_example_main.c"
    "decode_image.c"
    )

idf_component_register(SRCS ${srcs}
                    INCLUDE_DIRS "."
                    EMBED_FILES image.jpg
                    PRIV_REQUIRES clayZigESP32 esp_driver_gpio esp_driver_spi)


