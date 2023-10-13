#!/usr/bin/bash

set -u

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
BUILD_DIR=$SCRIPT_DIR/build
INSTALL_DIR=$SCRIPT_DIR/dist
MODULE_NEEDED="aes,auto_rng,cbc,checksum,modes,pbkdf2,sha2_32,sha2_64,system_rng"

ANDROID_API=28
ANDROID_ABI_SHOR=arm64
ANDROID_ABI_LONG=arm64-v8a
TARGET=

check_arch() {
    ANDROID_ABI_LONG=$1

    case $ANDROID_ABI_LONG in

    armeabi-v7a)
        ANDROID_ABI_SHOR=armv7
        TARGET=armv7a-none-linux-android$ANDROID_API
        ;;

    arm64-v8a)
        ANDROID_ABI_SHOR=arm64
        TARGET=aarch64-none-linux-android$ANDROID_API
        ;;

    x86)
        ANDROID_ABI_SHOR=non-x86_32
        TARGET=i686-none-linux-android$ANDROID_API
        ;;

    x86_64)
        ANDROID_ABI_SHOR=x86_64
        TARGET=x86_64-none-linux-android$ANDROID_API
        ;;

    *)
        echo "unknown android abi"
        exit 1
        ;;
    esac
}

build() {
    check_arch $1

    export AR="$ANDROID_NDK_BIN/llvm-ar"
    export CC="$ANDROID_NDK_BIN/clang --target=$TARGET"
    export CXX="$ANDROID_NDK_BIN/clang++ --target=$TARGET"
    export RANLIB="$ANDROID_NDK_BIN/llvm-ranlib"
    export STRIP="$ANDROID_NDK_BIN/llvm-strip"
    local SYSROOT="$(realpath "$ANDROID_NDK_BIN/../sysroot")"
    local OUTPUT_DIR="$INSTALL_DIR/android-botan/$ANDROID_ABI_LONG"

    rm -rf "$BUILD_DIR"

    "$SCRIPT_DIR/botan/configure.py" \
        --prefix="$OUTPUT_DIR" \
        --os=android --cc=clang --cpu=$ANDROID_ABI_SHOR \
        --with-build-dir="$BUILD_DIR" \
        --disable-shared-library \
        --optimize-for-size \
        --no-install-python-module \
        --without-documentation \
        --with-sysroot-dir="$SYSROOT" \
        --cxxflags="-fPIC -no-canonical-prefixes -Wno-macro-redefined -Wno-unknown-attributes -fvisibility=hidden -fvisibility-inlines-hidden -g -DANDROID -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security" \
        --build-targets="static" \
        --minimized-build --enable-modules="$MODULE_NEEDED"

    make -j$(nproc) -C $BUILD_DIR
    [[ $? -ne 0 ]] && exit $?

    make -C $BUILD_DIR install

    rm -rf "$OUTPUT_DIR/bin" "$OUTPUT_DIR/lib/pkgconfig"
    $STRIP --strip-debug "$OUTPUT_DIR/lib/libbotan-3.a"
}

rm -rf "$INSTALL_DIR"
build armeabi-v7a
build arm64-v8a
build x86_64

cat >>"$INSTALL_DIR/android-botan/AndroidBotan.cmake" <<EOF
set(ANDROID_BOTAN_DIR "\${CMAKE_CURRENT_LIST_DIR}/\${ANDROID_ABI}")
add_library(AndroidBotan STATIC IMPORTED)
set_property(TARGET AndroidBotan PROPERTY IMPORTED_LOCATION "\${ANDROID_BOTAN_DIR}/lib/libbotan-3.a")
target_compile_features(AndroidBotan INTERFACE cxx_std_20)
target_include_directories(
    AndroidBotan INTERFACE
    $<BUILD_INTERFACE:\${ANDROID_BOTAN_DIR}/include/botan-3/>
    $<INSTALL_INTERFACE:include>
)
unset(ANDROID_BOTAN_DIR)
EOF
