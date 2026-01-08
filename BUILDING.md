# Building XMRig for Android

This guide explains how to compile XMRig binaries for Android.

[繁體中文](BUILDING_zh-TW.md)

## Prerequisites

- **Android NDK** r26 or later
- **CMake** 3.22.1 or later  
- **Linux** or **macOS** build environment
- **Git**

## Step 1: Install Android NDK

### Option A: Android Studio
```bash
# Install via SDK Manager
# Tools → SDK Manager → SDK Tools → NDK (Side by side)
```

### Option B: Command Line
```bash
# Download NDK
wget https://dl.google.com/android/repository/android-ndk-r26c-linux.zip
unzip android-ndk-r26c-linux.zip
export ANDROID_NDK_HOME=$PWD/android-ndk-r26c
```

## Step 2: Clone and Modify XMRig

```bash
cd /tmp
git clone https://github.com/ImL1s/XMRigMiner-Android.git
cd xmrig
git checkout v6.21.0  # Use stable version
```

### Modify donate.h (設置捐贈地址)
```bash
# Edit src/donate.h to set donate level and wallet address
# 找到以下行並修改：

# 1. 設置默認捐贈級別為 1%
sed -i 's/kDefaultDonateLevel = 1/kDefaultDonateLevel = 1/' src/donate.h
sed -i 's/kMinimumDonateLevel = 1/kMinimumDonateLevel = 0/' src/donate.h

# 2. 手動編輯 src/donate.h，將捐贈地址改為：
# 8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC

# 在 src/donate.h 中找到類似以下的配置：
# static constexpr const char *kDonateHost = "...";
# 並替換為你的錢包地址和礦池信息
```

#### 詳細修改步驟
1. 打開 `src/donate.h` 文件
2. 找到捐贈錢包地址定義（通常在 `kDonatePool` 或類似的常量中）
3. 將地址修改為：`8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC`
4. 設置捐贈礦池為：`pool.supportxmr.com:3333` 或你選擇的礦池
5. 確認 `kDefaultDonateLevel = 1` (1%)

> **注意**: XMRig 的捐贈機制是在編譯時硬編碼的，必須重新編譯才能更改捐贈地址。

## Step 3: Create Build Script

```bash
cat > build_android.sh << 'EOF'
#!/bin/bash
set -e

# Configuration
NDK=$ANDROID_NDK_HOME
ANDROID_API=21
BUILD_DIR=build/android

# Build for arm64-v8a
echo "Building for arm64-v8a..."
mkdir -p $BUILD_DIR/arm64
cd $BUILD_DIR/arm64

cmake ../.. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-$ANDROID_API \
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

make -j$(nproc)
cd ../../..

# Build for armeabi-v7a
echo "Building for armeabi-v7a..."
mkdir -p $BUILD_DIR/arm32
cd $BUILD_DIR/arm32

cmake ../.. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=armeabi-v7a \
    -DANDROID_PLATFORM=android-$ANDROID_API \
    -DANDROID_STL=c++_shared \
    -DWITH_HWLOC=OFF \
    -DWITH_TLS=ON \
    -DWITH_HTTP=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_CUDA=OFF \
    -DBUILD_STATIC=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-O3 -march=armv7-a -mfpu=neon -ffast-math" \
    -DCMAKE_CXX_FLAGS="-O3 -march=armv7-a -mfpu=neon -ffast-math"

make -j$(nproc)
cd ../../..

echo "Build complete!"
echo "Binaries:"
echo "  - arm64: $BUILD_DIR/arm64/xmrig"
echo "  - arm32: $BUILD_DIR/arm32/xmrig"
EOF

chmod +x build_android.sh
```

## Step 4: Build

```bash
./build_android.sh
```

**Expected time**: 10-30 minutes depending on CPU

## Step 5: Verify Binaries

```bash
# Check arm64
file build/android/arm64/xmrig
# Expected: ELF 64-bit LSB executable, ARM aarch64

# Check arm32
file build/android/arm32/xmrig
# Expected: ELF 32-bit LSB executable, ARM, EABI5

# Check size (should be 2-5 MB each)
ls -lh build/android/arm64/xmrig
ls -lh build/android/arm32/xmrig
```

## Step 6: Copy to Android Project

```bash
# Copy binaries
cp build/android/arm64/xmrig \
   /path/to/XMRigMiner-Android/app/src/main/assets/xmrig_arm64

cp build/android/arm32/xmrig \
   /path/to/XMRigMiner-Android/app/src/main/assets/xmrig_arm32

# Set permissions
chmod 644 /path/to/XMRigMiner-Android/app/src/main/assets/xmrig_*
```

## Step 7: Rebuild Android App

```bash
cd /path/to/XMRigMiner-Android
./gradlew clean assembleDebug
```

## Troubleshooting

### CMake not found
```bash
# Install via SDK Manager or:
sudo apt-get install cmake  # Linux
brew install cmake          # macOS
```

### NDK path error
```bash
export ANDROID_NDK_HOME=/path/to/your/ndk
echo $ANDROID_NDK_HOME
```

### Build errors
- Ensure NDK r26+ is used
- Check CMake version (3.22.1+)
- Verify donate.h was modified
- Clean build directory: `rm -rf build/android`

### Binary too large
```bash
# Strip symbols to reduce size
$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip \
    build/android/arm64/xmrig
```

## Alternative: Pre-built Binaries

If compilation is too complex, you can use pre-built binaries:

⚠️ **Warning**: Only use trusted sources. Verify checksums.

```bash
# Example (DO NOT run blindly - verify source)
wget https://github.com/user/repo/releases/download/v6.21.0/xmrig-android-arm64
# Verify SHA256 checksum
sha256sum xmrig-android-arm64
```

## Verification

After integrating binaries, test:

```bash
# Install app
./gradlew installDebug

# Check logs
adb logcat | grep -i xmrig

# Verify binary execution
adb shell run-as com.iml1s.xmrigminer.debug ls -la files/xmrig
adb shell run-as com.iml1s.xmrigminer.debug ./files/xmrig --version
```

## Notes

- **File size**: ~2-5 MB per binary
- **Build time**: 10-30 minutes
- **Disk space**: ~500 MB for build artifacts
- **Memory**: 4GB+ RAM recommended

## Resources

- [XMRig Documentation](https://xmrig.com/docs)
- [Android NDK Guide](https://developer.android.com/ndk/guides)
- [CMake Android Guide](https://developer.android.com/ndk/guides/cmake)

---

**Last Updated**: 2026-01-03
