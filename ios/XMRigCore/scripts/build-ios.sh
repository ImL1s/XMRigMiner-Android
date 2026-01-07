#!/bin/bash
# Build XMRig for iOS (arm64)
# Produces: XMRigCore.xcframework

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
OUTPUT_DIR="$ROOT_DIR/output"

XMRIG_VERSION="6.25.0"
XMRIG_URL="https://github.com/xmrig/xmrig/archive/refs/tags/v${XMRIG_VERSION}.tar.gz"

echo "=== Building XMRig $XMRIG_VERSION for iOS ==="

# Create directories
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Paths to dependencies
LIBS_DIR="$ROOT_DIR/libs"
TOOLCHAIN="$LIBS_DIR/ios-cmake/ios.toolchain.cmake"
UV_DIR="$LIBS_DIR/libuv-1.48.0"
UV_LIB="$UV_DIR/build-ios/libuv.a"
UV_INC="$UV_DIR/include"

# Download XMRig if not exists
if [ ! -d "$BUILD_DIR/xmrig-$XMRIG_VERSION" ]; then
    echo "Downloading XMRig $XMRIG_VERSION..."
    curl -L "$XMRIG_URL" -o "$BUILD_DIR/xmrig.tar.gz"
    tar -xzf "$BUILD_DIR/xmrig.tar.gz" -C "$BUILD_DIR"
    rm "$BUILD_DIR/xmrig.tar.gz"
fi

XMRIG_SRC="$BUILD_DIR/xmrig-$XMRIG_VERSION"

# iOS arm64 build
echo "Building for iOS arm64 with ios-cmake..."
mkdir -p "$BUILD_DIR/ios-arm64"
cd "$BUILD_DIR/ios-arm64"

cmake "$XMRIG_SRC" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DPLATFORM=OS64 \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DARM_V8=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_OPENCL=OFF \
    -DWITH_CUDA=OFF \
    -DWITH_HWLOC=OFF \
    -DWITH_HTTP=OFF \
    -DWITH_TLS=OFF \
    -DWITH_ASM=OFF \
    -DBUILD_STATIC=ON \
    -DUV_LIBRARY="$UV_LIB" \
    -DUV_INCLUDE_DIR="$UV_INC" \
    -DCMAKE_C_FLAGS="-fembed-bitcode" \
    -DCMAKE_CXX_FLAGS="-fembed-bitcode"

make -j$(sysctl -n hw.ncpu)

# Create static library
echo "Creating combined static library with libtool..."
XMRIG_LIB="$BUILD_DIR/ios-arm64/libxmrig-notls.a"
ARGON2_LIB="$BUILD_DIR/ios-arm64/src/3rdparty/argon2/libargon2.a"
GHOSTRIDER_LIB="$BUILD_DIR/ios-arm64/src/crypto/ghostrider/libghostrider.a"
ETHASH_LIB="$BUILD_DIR/ios-arm64/src/3rdparty/libethash/libethash.a"

libtool -static -o "$OUTPUT_DIR/libxmrig-ios-arm64.a" \
    "$XMRIG_LIB" \
    "$ARGON2_LIB" \
    "$GHOSTRIDER_LIB" \
    "$ETHASH_LIB" \
    "$UV_LIB"

echo "=== Build Complete ==="
echo "Output: $OUTPUT_DIR/libxmrig-ios-arm64.a"
