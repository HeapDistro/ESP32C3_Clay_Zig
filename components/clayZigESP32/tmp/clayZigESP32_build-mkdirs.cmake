# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

# If CMAKE_DISABLE_SOURCE_CHANGES is set to true and the source directory is an
# existing directory in our source tree, calling file(MAKE_DIRECTORY) on it
# would cause a fatal error, even though it would be a no-op.
if(NOT EXISTS "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32")
  file(MAKE_DIRECTORY "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32")
endif()
file(MAKE_DIRECTORY
  "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-build"
  "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32"
  "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32/tmp"
  "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp"
  "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32/src"
  "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "C:/Users/Administrator/Downloads/esp32c3_zig_clay/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp${cfgdir}") # cfgdir has leading slash
endif()
