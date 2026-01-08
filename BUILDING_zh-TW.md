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
git clone https://github.com/ImL1s/XMRigMiner-Android.git
cd XMRigMiner-Android
git checkout v6.21.0  # 使用穩定版本
```

### 修改 donate.h (設置捐贈地址)
```bash
# 編輯 src/donate.h 以設置捐贈級別和錢包地址

# 1. 設置默認捐贈級別為 1%
sed -i 's/kDefaultDonateLevel = 1/kDefaultDonateLevel = 1/' src/donate.h
sed -i 's/kMinimumDonateLevel = 1/kMinimumDonateLevel = 0/' src/donate.h

# 2. 手動編輯 src/donate.h，將捐贈地址改為：
# 8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC
```

## 第 3 步：建立建置腳本... (略，參考 BUILDING.md)

## 第 6 步：複製到 Android 專案

```bash
cp build/android/arm64/xmrig \
   /path/to/XMRigMiner-Android/app/src/main/assets/xmrig_arm64
```

## 第 7 步：重新編譯 Android 應用

```bash
cd /path/to/XMRigMiner-Android
./gradlew clean assembleDebug
```

---

**最後更新**: 2026-01-03
