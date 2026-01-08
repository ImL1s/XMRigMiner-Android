#!/bin/bash
set -e

# XMRig Build Script for Android
# This script compiles XMRig binaries for ARM64 architecture
# with custom dev fee configuration (1% to app developer)

echo "======================================"
echo "XMRig Android Build Script"
echo "======================================"

# Configuration
XMRIG_VERSION="v6.21.0"
XMRIG_SRC_DIR="/tmp/xmrig"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$PROJECT_ROOT/app/src/main/assets"
CUSTOM_SOURCE_DIR="$PROJECT_ROOT/xmrig_custom_source"

# Check for Android NDK
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "❌ Error: ANDROID_NDK_HOME is not set"
    echo ""
    echo "Please set it to your NDK path:"
    echo "  export ANDROID_NDK_HOME=/path/to/ndk"
    echo ""
    echo "If using Android Studio NDK, try:"
    echo "  export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/26.3.11579264"
    exit 1
fi

echo "✓ NDK found: $ANDROID_NDK_HOME"

# Check for required tools
command -v cmake >/dev/null 2>&1 || {
    echo "❌ Error: cmake is not installed"
    echo "Install with: brew install cmake (macOS)"
    exit 1
}

command -v git >/dev/null 2>&1 || {
    echo "❌ Error: git is not installed"
    exit 1
}

echo "✓ Tools verified"

# Clone XMRig if not exists
if [ -d "$XMRIG_SRC_DIR" ]; then
    echo "⚠️  XMRig source exists, removing..."
    rm -rf "$XMRIG_SRC_DIR"
fi

echo "📥 Cloning XMRig $XMRIG_VERSION..."
git clone --depth 1 --branch "$XMRIG_VERSION" https://github.com/xmrig/xmrig.git "$XMRIG_SRC_DIR"

cd "$XMRIG_SRC_DIR"

# Apply custom dev fee configuration (1% to app developer)
echo "🔧 Applying custom dev fee configuration..."
if [ -f "$CUSTOM_SOURCE_DIR/donate.h" ]; then
    cp "$CUSTOM_SOURCE_DIR/donate.h" "$XMRIG_SRC_DIR/src/donate.h"
    echo "✓ Applied custom donate.h (1% dev fee)"
else
    echo "⚠️  Custom donate.h not found, using default"
fi

if [ -f "$CUSTOM_SOURCE_DIR/DonateStrategy.cpp" ]; then
    cp "$CUSTOM_SOURCE_DIR/DonateStrategy.cpp" "$XMRIG_SRC_DIR/src/net/strategies/DonateStrategy.cpp"
    echo "✓ Applied custom DonateStrategy.cpp (custom wallet)"
else
    echo "⚠️  Custom DonateStrategy.cpp not found, using default"
fi

# Verify wallet address in source
echo ""
echo "📋 Verifying dev fee wallet address..."
if grep -q "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC" "$XMRIG_SRC_DIR/src/net/strategies/DonateStrategy.cpp"; then
    echo "✓ Dev fee wallet address verified"
else
    echo "❌ Warning: Dev fee wallet address not found in source!"
    echo "   Please check xmrig_custom_source/DonateStrategy.cpp"
fi

# Build for ARM64
echo ""
echo "🔨 Building for arm64-v8a..."
BUILD_DIR="build/android/arm64"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake ../../.. \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-21 \
    -DANDROID_STL=c++_shared \
    -DWITH_HWLOC=OFF \
    -DWITH_TLS=ON \
    -DWITH_HTTP=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_CUDA=OFF \
    -DBUILD_STATIC=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-O3 -march=armv8-a+crypto -ffast-math" \
    -DCMAKE_CXX_FLAGS="-O3 -march=armv8-a+crypto -ffast-math"

make -j$(sysctl -n hw.ncpu 2>/dev/null || nproc)

cd "$XMRIG_SRC_DIR"

# Verify binary
if [ ! -f "$BUILD_DIR/xmrig" ]; then
    echo "❌ Error: Build failed, binary not found"
    exit 1
fi

echo ""
echo "✓ Build complete!"
file "$BUILD_DIR/xmrig"
ls -lh "$BUILD_DIR/xmrig"

# Strip binary to reduce size
echo ""
echo "🔧 Stripping binary..."
STRIP_TOOL="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip"
if [ ! -f "$STRIP_TOOL" ]; then
    STRIP_TOOL="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
fi

if [ -f "$STRIP_TOOL" ]; then
    "$STRIP_TOOL" "$BUILD_DIR/xmrig"
    echo "✓ Binary stripped"
    ls -lh "$BUILD_DIR/xmrig"
fi

# Copy to assets
echo ""
echo "📦 Copying to project assets..."
mkdir -p "$ASSETS_DIR"
cp "$BUILD_DIR/xmrig" "$ASSETS_DIR/xmrig_arm64"
chmod 644 "$ASSETS_DIR/xmrig_arm64"

echo ""
echo "======================================"
echo "✅ Build Complete!"
echo "======================================"
echo ""
echo "Binary location:"
echo "  $ASSETS_DIR/xmrig_arm64"
echo ""
echo "File size:"
ls -lh "$ASSETS_DIR/xmrig_arm64"
echo ""
echo "Dev Fee: 1% to wallet:"
echo "  8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_ROOT"
echo "  2. ./gradlew clean assembleDebug"
echo "  3. ./gradlew installDebug"
echo ""
