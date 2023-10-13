cmake_minimum_required(VERSION 3.25)

project(AndroidBotan)

set(BOTAN_DIR ${CMAKE_CURRENT_LIST_DIR}/dist/${ANDROID_ABI})

add_library(AndroidBotan STATIC IMPORTED)
set_property(TARGET AndroidBotan PROPERTY IMPORTED_LOCATION "${BOTAN_DIR}/lib/libbotan-3.a")
target_compile_features(AndroidBotan INTERFACE cxx_std_20)
target_include_directories(
    AndroidBotan INTERFACE
    $<BUILD_INTERFACE:${BOTAN_DIR}/include/botan-3/>
    $<INSTALL_INTERFACE:include>
)

unset(BOTAN_DIR)