# 為 Android 編譯 XMRig

本指南說明如何為 Android 編譯 XMRig 二進制文件。

## 前置條件

- **Android NDK** r26 或更高版本
- **CMake** 3.22.1 或更高版本
- **Linux** 或 **macOS** 建置環境
- **Git**

## 第 1 步：安裝 Android NDK

### 選項 A：使用 Android Studio
```bash
# 通過 SDK Manager 安裝
# Tools → SDK Manager → SDK Tools → NDK (Side by side)
```

### 選項 B：使用命令行
```bash
# 下載 NDK
wget https://dl.google.com/android/repository/android-ndk-r26c-linux.zip
unzip android-ndk-r26c-linux.zip
export ANDROID_NDK_HOME=$PWD/android-ndk-r26c
```

## 第 2 步：複製並修改 XMRig

```bash
cd /tmp
git clone https://github.com/xmrig/xmrig.git
cd xmrig
git checkout v6.21.0  # 使用穩定版本
```

### 修改 donate.h (設置捐贈地址)
```bash
# 編輯 src/donate.h 以設置捐贈級別和錢包地址

# 1. 設置默認捐贈級別為 1%
sed -i 's/kDefaultDonateLevel = 1/kDefaultDonateLevel = 1/' src/donate.h
sed -i 's/kMinimumDonateLevel = 1/kMinimumDonateLevel = 0/' src/donate.h

# 2. 手動編輯 src/donate.h，將捐贈地址改為你的地址
```

> **注意**: XMRig 的捐贈機制是在編譯時硬編碼的，必須重新編譯才能更改捐贈地址。

## 第 3 步：建立建置腳本

```bash
cat > build_android.sh << 'EOF'
#!/bin/bash
set -e

NDK=$ANDROID_NDK_HOME
ANDROID_API=21
BUILD_DIR=build/android

# 編譯 arm64-v8a
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

echo "Build complete!"
EOF

chmod +x build_android.sh
```

## 第 4 步：開始編譯

```bash
./build_android.sh
```

## 第 5 步：驗證二進制文件

```bash
file build/android/arm64/xmrig
# 應顯示: ELF 64-bit LSB executable, ARM aarch64
```

## 第 6 步：複製到 Android 專案

```bash
cp build/android/arm64/xmrig \
   /path/to/XMRigMiner/app/src/main/assets/xmrig_arm64
```

## 第 7 步：重新編譯 Android 應用

```bash
./gradlew clean assembleDebug
```

---

**最後更新**: 2025-10-30
