
idf_component_register()

include(ExternalProject)


# External build process for libclayZigESP32, runs in source dir and
# produces libclayZigESP32.a
externalproject_add(clayZigESP32_build
    PREFIX ${COMPONENT_DIR}
    SOURCE_DIR ${COMPONENT_DIR}
    CONFIGURE_COMMAND ""
    BUILD_IN_SOURCE 0
    BUILD_DIR ${COMPONENT_DIR}/zig-out/lib
    BUILD_COMMAND zig build -Doptimize=ReleaseSafe
    INSTALL_COMMAND ""
    )

# Add libclayZigESP32.a to the build process
add_library(clayZigESP32 STATIC IMPORTED GLOBAL)
add_dependencies(clayZigESP32 clayZigESP32_build)

set_target_properties(clayZigESP32 PROPERTIES IMPORTED_LOCATION
    ${COMPONENT_DIR}/zig-out/lib/libclayZigESP32.a)

#add_prebuilt_library(clayZigESP32 "${COMPONENT_DIR}/zig-out/lib/libclayZigESP32.a")
#add_dependencies(clayZigESP32 clayZigESP32_build)

target_link_libraries(${COMPONENT_LIB} INTERFACE clayZigESP32)

#set_directory_properties( PROPERTIES ADDITIONAL_CLEAN_FILES
#"${COMPONENT_DIR}/zig-out/lib/libclayZigESP32.a")

