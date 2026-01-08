#!/bin/bash
# Build XMRig for iOS (arm64)
# Produces: libxmrig-ios-arm64.a
# with custom dev fee configuration (1% to app developer)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
OUTPUT_DIR="$ROOT_DIR/output"
PROJECT_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
CUSTOM_SOURCE_DIR="$PROJECT_ROOT/xmrig_custom_source"

XMRIG_VERSION="6.21.0"
XMRIG_URL="https://github.com/xmrig/xmrig/archive/refs/tags/v${XMRIG_VERSION}.tar.gz"

echo "=== Building XMRig $XMRIG_VERSION for iOS ==="
echo "Dev Fee: 1%"

# Create directories
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Paths to dependencies
LIBS_DIR="$ROOT_DIR/libs"
TOOLCHAIN="$LIBS_DIR/ios-cmake/ios.toolchain.cmake"
UV_DIR="$LIBS_DIR/libuv-1.48.0"
UV_LIB="$UV_DIR/build-ios/libuv.a"
UV_INC="$UV_DIR/include"

# Check dependencies
if [ ! -f "$TOOLCHAIN" ]; then
    echo "❌ Error: ios-cmake toolchain not found"
    echo "Please ensure ios-cmake is at: $TOOLCHAIN"
    exit 1
fi

if [ ! -f "$UV_LIB" ]; then
    echo "❌ Error: libuv not built"
    echo "Please build libuv first: cd $UV_DIR && ./build-ios.sh"
    exit 1
fi

# Download XMRig if not exists
if [ ! -d "$BUILD_DIR/xmrig-$XMRIG_VERSION" ]; then
    echo "Downloading XMRig $XMRIG_VERSION..."
    curl -L "$XMRIG_URL" -o "$BUILD_DIR/xmrig.tar.gz"
    tar -xzf "$BUILD_DIR/xmrig.tar.gz" -C "$BUILD_DIR"
    rm "$BUILD_DIR/xmrig.tar.gz"
fi

XMRIG_SRC="$BUILD_DIR/xmrig-$XMRIG_VERSION"

echo "Syncing bridge source files..."
cp "$ROOT_DIR/src/xmrig_bridge_impl.cpp" "$XMRIG_SRC/src/"
cp "$ROOT_DIR/include/xmrig_bridge.h" "$XMRIG_SRC/src/"

# Apply custom dev fee configuration
echo ""
echo "🔧 Applying custom dev fee configuration..."
if [ -f "$CUSTOM_SOURCE_DIR/donate.h" ]; then
    cp "$CUSTOM_SOURCE_DIR/donate.h" "$XMRIG_SRC/src/donate.h"
    echo "✓ Applied custom donate.h (1% dev fee)"
else
    echo "⚠️  Custom donate.h not found at $CUSTOM_SOURCE_DIR/donate.h"
fi

if [ -f "$CUSTOM_SOURCE_DIR/DonateStrategy.cpp" ]; then
    cp "$CUSTOM_SOURCE_DIR/DonateStrategy.cpp" "$XMRIG_SRC/src/net/strategies/DonateStrategy.cpp"
    echo "✓ Applied custom DonateStrategy.cpp (custom wallet)"
else
    echo "⚠️  Custom DonateStrategy.cpp not found at $CUSTOM_SOURCE_DIR/DonateStrategy.cpp"
fi

# Verify wallet address
echo ""
echo "📋 Verifying dev fee wallet address..."
if grep -q "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC" "$XMRIG_SRC/src/net/strategies/DonateStrategy.cpp" 2>/dev/null; then
    echo "✓ Dev fee wallet address verified"
else
    echo "⚠️  Warning: Dev fee wallet address not found in source"
fi

# iOS arm64 build
echo ""
echo "🔨 Building for iOS arm64 with ios-cmake..."
rm -rf "$BUILD_DIR/ios-arm64"
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
echo ""
echo "📦 Creating combined static library with libtool..."
XMRIG_LIB="$BUILD_DIR/ios-arm64/libxmrig-notls.a"
ARGON2_LIB="$BUILD_DIR/ios-arm64/src/3rdparty/argon2/libargon2.a"
GHOSTRIDER_LIB="$BUILD_DIR/ios-arm64/src/crypto/ghostrider/libghostrider.a"
ETHASH_LIB="$BUILD_DIR/ios-arm64/src/3rdparty/libethash/libethash.a"

# Find available libraries
LIBS_TO_COMBINE="$UV_LIB"
[ -f "$XMRIG_LIB" ] && LIBS_TO_COMBINE="$LIBS_TO_COMBINE $XMRIG_LIB"
[ -f "$ARGON2_LIB" ] && LIBS_TO_COMBINE="$LIBS_TO_COMBINE $ARGON2_LIB"
[ -f "$GHOSTRIDER_LIB" ] && LIBS_TO_COMBINE="$LIBS_TO_COMBINE $GHOSTRIDER_LIB"
[ -f "$ETHASH_LIB" ] && LIBS_TO_COMBINE="$LIBS_TO_COMBINE $ETHASH_LIB"

libtool -static -o "$OUTPUT_DIR/libxmrig-ios-arm64.a" $LIBS_TO_COMBINE

echo ""
echo "=== Build Complete ==="
echo "Output: $OUTPUT_DIR/libxmrig-ios-arm64.a"
echo ""
echo "Dev Fee: 1% to wallet:"
echo "  8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC"
echo ""
ls -lh "$OUTPUT_DIR/libxmrig-ios-arm64.a"
