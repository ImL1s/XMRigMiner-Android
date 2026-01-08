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

# Patch CMakeLists.txt to include the bridge source file
echo "Patching CMakeLists.txt to include bridge..."
if ! grep -q "xmrig_bridge_impl.cpp" "$XMRIG_SRC/CMakeLists.txt"; then
    # Add bridge source to SOURCES list by inserting after the set(SOURCES line
    # Use awk for more reliable multi-line insertion
    awk '/^set\(SOURCES$/ { print; print "    src/xmrig_bridge_impl.cpp"; next } 1' "$XMRIG_SRC/CMakeLists.txt" > "$XMRIG_SRC/CMakeLists.txt.tmp"
    mv "$XMRIG_SRC/CMakeLists.txt.tmp" "$XMRIG_SRC/CMakeLists.txt"
    echo "✓ Added xmrig_bridge_impl.cpp to build"
else
    echo "✓ Bridge already in CMakeLists.txt"
fi

# Fix CMakeLists.txt bug: remove problematic add_custom_command that references wrong target
# This strip command is not needed for iOS static library builds anyway
echo "Patching CMakeLists.txt to fix target reference bug..."
sed -i '' 's/add_custom_command(TARGET \${PROJECT_NAME}/# DISABLED for iOS: add_custom_command(TARGET \${PROJECT_NAME}/' "$XMRIG_SRC/CMakeLists.txt"

# Change add_executable to add_library for iOS static library build
echo "Patching CMakeLists.txt to build static library instead of executable..."
sed -i '' 's/add_executable(\${CMAKE_PROJECT_NAME}/add_library(\${CMAKE_PROJECT_NAME} STATIC/' "$XMRIG_SRC/CMakeLists.txt"

# Patch iOS-specific compatibility issues
echo "Patching XMRig source for iOS compatibility..."

# Fix pthread_jit_write_protect_np - not available on iOS
# Wrap the calls in #if !TARGET_OS_IOS
sed -i '' 's/pthread_jit_write_protect_np(false);/#if !TARGET_OS_IOS\n    pthread_jit_write_protect_np(false);\n#endif/' "$XMRIG_SRC/src/crypto/common/VirtualMemory_unix.cpp"
sed -i '' 's/pthread_jit_write_protect_np(true);/#if !TARGET_OS_IOS\n    pthread_jit_write_protect_np(true);\n#endif/' "$XMRIG_SRC/src/crypto/common/VirtualMemory_unix.cpp"

# Add TargetConditionals.h include if not present
if ! grep -q "TargetConditionals.h" "$XMRIG_SRC/src/crypto/common/VirtualMemory_unix.cpp"; then
    sed -i '' '1i\
#include <TargetConditionals.h>
' "$XMRIG_SRC/src/crypto/common/VirtualMemory_unix.cpp"
fi

# Patch Base.cpp to check XMRIG_CONFIG_PATH environment variable first
echo "Patching Base.cpp for iOS config path..."
cat > "$XMRIG_SRC/src/base/kernel/Base.cpp.patch" << 'BASE_PATCH_EOF'
--- a/src/base/kernel/Base.cpp
+++ b/src/base/kernel/Base.cpp
@@ -19,6 +19,8 @@
 #include <cassert>
 #include <memory>

+#include <cstdlib>
+

 #include "base/kernel/Base.h"
 #include "base/io/json/Json.h"
@@ -128,6 +130,17 @@ private:
             return config.release();
         }

+        // iOS: Check XMRIG_CONFIG_PATH environment variable first
+        const char* ios_config = std::getenv("XMRIG_CONFIG_PATH");
+        if (ios_config && ios_config[0] != '\0') {
+            chain.addFile(ios_config);
+            if (read(chain, config)) {
+                return config.release();
+            }
+        }
+
         chain.addFile(Process::location(Process::DataLocation, "config.json"));
         if (read(chain, config)) {
             return config.release();
BASE_PATCH_EOF

# Apply the patch using a more reliable method - direct file modification
if ! grep -q "XMRIG_CONFIG_PATH" "$XMRIG_SRC/src/base/kernel/Base.cpp"; then
    # Insert the include for cstdlib
    sed -i '' 's/#include <memory>/#include <memory>\n\n#include <cstdlib>/' "$XMRIG_SRC/src/base/kernel/Base.cpp"

    # Insert the environment variable check before the DataLocation check
    # Find the line with "chain.addFile(Process::location(Process::DataLocation" and insert before it
    sed -i '' '/chain.addFile(Process::location(Process::DataLocation, "config.json"));/i\
\        \/\/ iOS: Check XMRIG_CONFIG_PATH environment variable first\
\        const char* ios_config = std::getenv("XMRIG_CONFIG_PATH");\
\        if (ios_config \&\& ios_config[0] != '"'"'\\0'"'"') {\
\            chain.addFile(ios_config);\
\            if (read(chain, config)) {\
\                return config.release();\
\            }\
\        }\
' "$XMRIG_SRC/src/base/kernel/Base.cpp"
    echo "✓ Patched Base.cpp for iOS config path"
else
    echo "✓ Base.cpp already patched"
fi
rm -f "$XMRIG_SRC/src/base/kernel/Base.cpp.patch"

# Fix Platform_mac.cpp for iOS - replace with iOS-compatible version
cat > "$XMRIG_SRC/src/base/kernel/Platform_mac.cpp" << 'PLATFORM_EOF'
#include <TargetConditionals.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <uv.h>
#include <thread>
#include <fstream>

#if !TARGET_OS_IOS
#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPowerSources.h>
#endif

#include "base/kernel/Platform.h"
#include "version.h"

char *xmrig::Platform::createUserAgent()
{
    constexpr const size_t max = 256;
    char *buf = new char[max]();
    int length = snprintf(buf, max,
                          "%s/%s (iOS"
#                         ifdef XMRIG_ARM
                          "; arm64"
#                         else
                          "; x86_64"
#                         endif
                          ") libuv/%s", APP_NAME, APP_VERSION, uv_version_string());

#   ifdef __clang__
    length += snprintf(buf + length, max - length, " clang/%d.%d.%d", __clang_major__, __clang_minor__, __clang_patchlevel__);
#   elif defined(__GNUC__)
    length += snprintf(buf + length, max - length, " gcc/%d.%d.%d", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
#   endif

    return buf;
}

bool xmrig::Platform::setThreadAffinity(uint64_t cpu_id)
{
    return true;
}

void xmrig::Platform::setProcessPriority(int)
{
}

void xmrig::Platform::setThreadPriority(int priority)
{
    if (priority == -1) {
        return;
    }

    int prio = 19;
    switch (priority) {
    case 1: prio = 5; break;
    case 2: prio = 0; break;
    case 3: prio = -5; break;
    case 4: prio = -10; break;
    case 5: prio = -15; break;
    default: break;
    }

    setpriority(PRIO_PROCESS, 0, prio);
}

bool xmrig::Platform::isOnBatteryPower()
{
#if TARGET_OS_IOS
    return false; // iOS - assume plugged in for mining
#else
    return IOPSGetTimeRemainingEstimate() != kIOPSTimeRemainingUnlimited;
#endif
}

uint64_t xmrig::Platform::idleTime()
{
#if TARGET_OS_IOS
    return 0; // iOS - no idle time detection
#else
    uint64_t idle_time  = 0;
    const auto service  = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOHIDSystem"));
    const auto property = IORegistryEntryCreateCFProperty(service, CFSTR("HIDIdleTime"), kCFAllocatorDefault, 0);
    CFNumberGetValue((CFNumberRef)property, kCFNumberSInt64Type, &idle_time);
    CFRelease(property);
    IOObjectRelease(service);
    return idle_time / 1000000U;
#endif
}
PLATFORM_EOF
echo "✓ Patched Platform_mac.cpp for iOS"

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

if [ -f "$CUSTOM_SOURCE_DIR/DonateStrategy.h" ]; then
    cp "$CUSTOM_SOURCE_DIR/DonateStrategy.h" "$XMRIG_SRC/src/net/strategies/DonateStrategy.h"
    echo "✓ Applied custom DonateStrategy.h"
else
    echo "⚠️  Custom DonateStrategy.h not found at $CUSTOM_SOURCE_DIR/DonateStrategy.h"
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
