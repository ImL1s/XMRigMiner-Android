# XMRig Miner - Multi-Platform Support

Cross-platform Monero/Wownero/DERO mining application.

## Supported Platforms

| Platform | Type | Status | Mining | Notes |
|----------|------|--------|--------|-------|
| **Android** | Mobile | ✅ Ready | ✅ Native XMRig | ARM64 native mining |
| **iOS** | Mobile | ✅ Ready | ⚠️ Limited | Apple restricts background CPU |
| **Web** | Browser | ✅ Ready | ✅ RandomX.js | WebSocket proxy required |
| **macOS** | Desktop | ✅ Ready | ✅ Native XMRig | Full performance |
| **Windows** | Desktop | ✅ Ready | ✅ Native XMRig | Full performance |
| **Linux** | Desktop | ✅ Ready | ✅ Native XMRig | Full performance |
| **WearOS** | Watch | ✅ Ready | ❌ No | Companion app only |
| **watchOS** | Watch | ✅ Ready | ❌ No | Stats viewer only (Apple ban) |

---

## Desktop Application (macOS/Windows/Linux)

Built with **Tauri 2.0** for native performance with minimal bundle size.

### Features
- Native XMRig integration
- Real-time hashrate monitoring
- Multi-coin support (XMR, WOW, DERO)
- Auto-update capability
- System tray support

### Build

```bash
cd desktop

# Install dependencies
npm install

# Download XMRig binary for your platform
./scripts/build-xmrig.sh

# Development
npm run tauri:dev

# Production build
npm run tauri:build
```

### Output
- **macOS**: `target/release/bundle/dmg/XMRig Miner.dmg`
- **Windows**: `target/release/bundle/nsis/XMRig Miner Setup.exe`
- **Linux**: `target/release/bundle/appimage/XMRig Miner.AppImage`

---

## WearOS Companion App

Companion app for Android smartwatches running Wear OS 3.0+.

### Features
- View mining stats from phone
- Start/Stop mining remotely
- Tile for quick stats view
- Complications for watch faces

### Build

```bash
cd wearos

# Build APK
./gradlew assembleRelease

# Install on watch
adb -s <watch-id> install app/build/outputs/apk/release/app-release.apk
```

### Requirements
- Wear OS 3.0+ (API 30+)
- Main XMRig Miner app installed on phone
- Phone and watch paired

---

## watchOS Stats Viewer

Stats viewer for Apple Watch. **Note: Apple prohibits mining apps.**

> ⚠️ **Apple App Store Guidelines 2.4.2**: "Apps, including any third-party advertisements displayed within them, may not run unrelated background processes, such as cryptocurrency mining."

### Features
- View hashrate and stats
- Control mining on connected iPhone/Mac
- Watch face complications
- Quick glance at mining status

### Build

```bash
cd watchos

# Open in Xcode
open XMRigWatch.xcodeproj

# Build for simulator or device
```

### Requirements
- watchOS 9.0+
- iPhone with iOS companion app
- WatchConnectivity framework

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Mining Backend                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   XMRig     │  │ RandomX.js  │  │  XMRig      │              │
│  │  (Native)   │  │  (WASM)     │  │ (Embedded)  │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│        ↑                ↑                ↑                       │
│  Desktop/Android      Web            iOS                         │
└─────────────────────────────────────────────────────────────────┘
                              ↑
                    Communication Layer
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│                     Companion Apps                               │
│  ┌─────────────┐              ┌─────────────┐                   │
│  │   WearOS    │◄────────────►│   watchOS   │                   │
│  │  (Android)  │   Wearable   │   (Apple)   │                   │
│  │             │   Data API   │             │                   │
│  └─────────────┘              └─────────────┘                   │
│        ↑                            ↑                            │
│   Phone Mining                iPhone/Mac                         │
│    Control                     Control                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Performance Comparison

| Platform | Expected Hashrate | Power Usage | Notes |
|----------|-------------------|-------------|-------|
| Desktop (AMD Ryzen 9) | 15,000+ H/s | High | Best performance |
| Desktop (Apple M2) | 2,500+ H/s | Medium | Efficient |
| Android (SD 8 Gen 2) | 800-1,200 H/s | Medium | Thermal throttling |
| Web (Chrome) | 100-200 H/s | Low | JavaScript limitations |
| iOS | Limited | Low | Background restrictions |
| WearOS | N/A | - | Companion only |
| watchOS | N/A | - | Companion only |

---

## Development

### Prerequisites

- **Desktop**: Rust 1.70+, Node.js 20+, Tauri CLI
- **Android**: Android Studio, NDK 26+
- **iOS**: Xcode 15+, macOS 14+
- **WearOS**: Android Studio, Wear OS emulator
- **watchOS**: Xcode 15+, watchOS Simulator

### Quick Start

```bash
# Clone repository
git clone https://github.com/iml1s/xmrig-android.git
cd xmrig-android

# Desktop
cd desktop && npm install && npm run tauri:dev

# Android
./gradlew assembleDebug

# iOS
cd ios && open XMRigMiner-iOS.xcodeproj

# WearOS
cd wearos && ./gradlew assembleDebug

# watchOS
cd watchos && open XMRigWatch.xcodeproj

# Web
cd web && npm install && npm run dev
```

---

## Developer Fee

All platforms include a **1% developer fee** to support ongoing development.

| Platform | Fee Implementation | Wallet |
|----------|-------------------|--------|
| Android | XMRig built-in + DevFeeManager.kt | ✅ |
| iOS | XMRig built-in | ✅ |
| Desktop | XMRig built-in | ✅ |
| Web | Proxy server (server.js) | ✅ |

**Developer Wallet:**
```
8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC
```

See [DEV_FEE.md](DEV_FEE.md) for detailed explanation.

---

## Building XMRig with Custom Dev Fee

All build scripts automatically apply custom dev fee configuration from `xmrig_custom_source/`:

```bash
# Android
./scripts/build_xmrig.sh

# iOS
cd ios/XMRigCore/scripts && ./build-ios.sh

# Desktop
cd desktop/scripts && ./build-xmrig.sh
```

---

## License

GPLv3 License - See LICENSE file for details.

XMRig is licensed under GPLv3.
