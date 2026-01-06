# XMRig Miner (Android + Web)

[![Android CI/CD](https://github.com/ImL1s/xmrig-android/actions/workflows/release.yml/badge.svg)](https://github.com/ImL1s/xmrig-android/actions/workflows/release.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A **cross-platform** Monero (XMR) mining solution:
- **📱 Android App**: Native Android miner based on XMRig 6.21.0 with Material Design 3 UI.
- **🌐 Web Miner**: Browser-based miner using RandomX.js (WebAssembly), works on any platform.

[繁體中文](README_zh-TW.md)

## 📱 Features

### Core Features
- ✅ **Full XMRig Integration** - Based on XMRig 6.21.0, supports RandomX algorithm.
- 🎯 **Native Performance Optimization** - Compiled with C++ NDK, optimized for ARMv8 (64-bit).
- 📊 **Real-time Monitoring** - Real-time display of hashrate, difficulty, CPU usage, temperature, etc.
- 🔧 **Flexible Configuration** - Complete pool configuration, thread management, and performance tuning options.
- 🌐 **Multi-pool Support** - Supports major Monero pools (SupportXMR, MoneroOcean, etc.).
- 💾 **Configuration Persistence** - Uses DataStore to save user settings.

### Monitoring Features
- **Hashrate Monitoring**
  - 10s/60s/15m average hashrate
  - Peak hashrate record
  - Real-time hashrate graph
  
- **System Monitoring**
  - CPU usage (attempts to read /proc/stat, may be restricted on Android 11+)
  - Device temperature monitoring
  - Battery and charging status
  - Network connection status

- **Mining Status**
  - Accepted/Rejected shares
  - Current difficulty
  - Pool connection status
  - XMRig log output

### Security Features
- 🔒 **Developer Donation** - donate-level = 1% to support the developer.
- 🔐 **Privacy Protection** - No user data collection.
- 🛡️ **Open Source & Transparent** - Full source code available.

---

## 🌐 Web Miner (New!)

Mine Monero directly in your browser - no installation required!

### Features
- **Pure JavaScript + WebAssembly** - Uses `randomx.js` for native-like performance.
- **Multi-Pool Support** - MoneroOcean, SupportXMR, HashVault, 2Miners.
- **Dynamic Pool Selection** - Switch pools without restarting.
- **Real-time Stats** - Hashrate, shares, uptime display.

### Quick Start (Web Miner)
```bash
# 1. Start the WebSocket-to-Stratum proxy
cd web/proxy && node server.js

# 2. Start the Vite dev server
cd web && npm run dev

# 3. Open http://localhost:5173
```

### Expected Performance
- **Desktop Browser**: ~40-80 H/s (varies by CPU)
- **Mobile Browser**: ~10-30 H/s

> ⚠️ **Note**: Web mining has lower hashrate compared to native apps due to browser sandboxing.

---

### Developer Donation
This application has a 1% donation level to support continuous maintenance and improvement.
- **Donation Rate**: 1%
- **Donation Address**: 85E5c5FcCYJ3UPmebJ1cLENY5siXFTakjTkWperAbZzSJBuwrh3vBBFAxT7xFPp2tCAY4mAs4Qj1gUWBze23pWCES9kgBQu
- **Transparency**: All donation settings are openly visible in the source code.
- **How it works**: XMRig switches to the developer's wallet address for 1% of the mining time.

> **Note**: Since XMRig's donation address is hardcoded during compilation, you must recompile XMRig to use a custom donation address. Currently, the official default XMRig donation address is used. If you wish to support this project's developer, you can direct donate XMR to the address above.

## 🏗️ Technical Architecture

### Tech Stack
- **Language**: Kotlin 1.9.20
- **UI Framework**: Jetpack Compose (Material Design 3)
- **Architecture**: MVVM + Clean Architecture
- **Dependency Injection**: Hilt (Dagger)
- **Asynchronous**: Kotlin Coroutines + Flow
- **Persistence**: DataStore (Preferences) + Room
- **Background Tasks**: WorkManager
- **Native Layer**: C++ (XMRig 6.21.0)
- **Build Tools**: Gradle 8.2.0 + AGP 8.2.0

### Project Structure
```
app/
├── src/
│   ├── main/
│   │   ├── java/com/iml1s/xmrigminer/
│   │   │   ├── data/              # Data layer
│   │   │   │   ├── model/         # Data models
│   │   │   │   └── repository/    # Repositories
│   │   │   ├── domain/            # Domain layer (Business logic)
│   │   │   ├── presentation/      # Presentation layer
│   │   │   │   ├── config/        # Config UI
│   │   │   │   ├── mining/        # Mining UI
│   │   │   │   └── stats/         # Stats UI
│   │   │   ├── service/           # Background services
│   │   │   │   ├── MiningWorker.kt    # Mining Worker
│   │   │   │   └── MonitorWorker.kt   # Monitoring Worker
│   │   │   ├── native/            # JNI bridge
│   │   │   └── di/                # Dependency injection
│   │   ├── cpp/                   # C++ native code
│   │   │   └── native-bridge.cpp  # XMRig bridge layer
│   │   └── res/                   # Resource files
│   └── xmrig/                     # XMRig source
│       └── libs/                  # Pre-compiled XMRig libs
└── build.gradle.kts
```

## 🚀 Quick Start

### Requirements
- Android Studio Hedgehog (2023.1.1) or higher
- Android SDK 34
- NDK 26.1.10909125
- CMake 3.22.1
- JDK 17
- Gradle 8.2+

### Build Steps

1. **Clone the Repo**
```bash
git clone https://github.com/ImL1s/XMRigMiner-Android.git
cd XMRigMiner-Android
```

2. **Configure NDK**
Ensure your `local.properties` has the NDK path:
```properties
ndk.dir=/Users/<username>/Library/Android/sdk/ndk/26.3.11579264
```

3. **Sync Dependencies**
```bash
./gradlew clean build
```

4. **Build APK**
```bash
# Debug version
./gradlew assembleDebug

# Release version
./gradlew assembleRelease
```

### Running the App

1. Connect an Android device or start an emulator (physical device recommended).
2. Click the "Run" button in Android Studio.
3. Or use the command line:
```bash
./gradlew installDebug
```

## 📱 Usage Instructions

### Initial Setup

1. **Wallet Configuration**
   - Enter your Monero wallet address.
   - Select a pool (Default: pool.supportxmr.com:3333).
   - Set a worker name (optional).

2. **Performance Tuning**
   - **Threads**: Defaults to CPU cores - 1.
   - **Max CPU Usage**: Recommended at 75% to avoid overheating.
   - **TLS Encryption**: Recommended for security.

3. **Advanced Options**
   - Auto-reconnect: Automatically reconnects on network loss.
   - Background Mining: Continue mining when the screen is off.

### Start Mining
1. Click the "Start Mining" button.
2. The app starts the XMRig process in the background.
3. The dashboard will show real-time stats.

### Stop Mining
Click the "Stop Mining" button to safely terminate the process.

## ⚙️ Configuration Details

### Recommended Pools

#### SupportXMR
```
URL: pool.supportxmr.com:3333
TLS: Recommended
Min Payout: 0.1 XMR
```

#### MoneroOcean
```
URL: gulf.moneroocean.stream:10128
TLS: Recommended
Algo-switching: Automatically switches to the most profitable coin.
```

## 📊 Performance Data

Based on actual tests:

### Test Device
- CPU: ARM Cortex-A55 (8 cores)
- RAM: 5.5 GB
- Temperature: 30-38°C

### Hashrate
- **Average**: 250-350 H/s
- **Peak**: 348 H/s
- **Stability**: Good

## 🔧 Known Issues

### CPU Monitoring Failure
```
Error: EACCES (Permission denied) reading /proc/stat
```
**Cause**: Android 11+ restricts access to `/proc/stat`.
**Status**: Implemented but might not work on newer Android versions.

### File Permissions
Earlier versions had issues executing binaries in the `files/` directory.
**Solution**: XMRig is now compiled as a `.so` library and loaded from `lib/`.

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

### XMRig License
XMRig uses the GPLv3 license: https://github.com/xmrig/xmrig

## ⚠️ Disclaimer
- For educational and research purposes only.
- Mining can cause device overheating and battery wear.
- Use responsibly and at your own risk.
