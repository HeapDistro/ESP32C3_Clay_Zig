# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file LICENSE.rst or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION ${CMAKE_VERSION}) # this file comes with cmake

# If CMAKE_DISABLE_SOURCE_CHANGES is set to true and the source directory is an
# existing directory in our source tree, calling file(MAKE_DIRECTORY) on it
# would cause a fatal error, even though it would be a no-op.
if(NOT EXISTS "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32")
  file(MAKE_DIRECTORY "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32")
endif()
file(MAKE_DIRECTORY
  "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-build"
  "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32"
  "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32/tmp"
  "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp"
  "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32/src"
  "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/home/asurans/Downloads/esp32c3_sample/lcd_dev/components/clayZigESP32/src/clayZigESP32_build-stamp${cfgdir}") # cfgdir has leading slash
endif()
