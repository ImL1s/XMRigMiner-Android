# XMRig Miner - Multi-Platform

[![Android CI](https://github.com/ImL1s/xmrig-android/actions/workflows/android-ci.yml/badge.svg)](https://github.com/ImL1s/xmrig-android/actions/workflows/android-ci.yml)
[![Web Miner CI](https://github.com/ImL1s/xmrig-android/actions/workflows/web-miner-ci.yml/badge.svg)](https://github.com/ImL1s/xmrig-android/actions/workflows/web-miner-ci.yml)
[![Release](https://github.com/ImL1s/xmrig-android/actions/workflows/release.yml/badge.svg)](https://github.com/ImL1s/xmrig-android/actions/workflows/release.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Cross-platform **Monero (XMR) / Wownero (WOW) / DERO** mining solution.

| Platform | Status | Mining | Notes |
|----------|--------|--------|-------|
| 📱 **Android** | ✅ Ready | Native XMRig | ARM64 native, best mobile performance |
| 🍎 **iOS** | ✅ Ready | Native XMRig | Sideload only (Apple prohibits mining) |
| 🌐 **Web** | ✅ Ready | RandomX.js | Any browser, no installation |
| 💻 **Desktop** | ✅ Ready | Native XMRig | macOS / Windows / Linux |
| ⌚ **WearOS** | ✅ Ready | Companion | Stats viewer & remote control |
| ⌚ **watchOS** | ✅ Ready | Companion | Stats viewer only (Apple ban) |

[繁體中文](README_zh-TW.md) | [Platform Details](PLATFORMS.md) | [Dev Fee Info](DEV_FEE.md)

---

## Quick Start

### Android
```bash
./gradlew assembleDebug
./gradlew installDebug
```

### iOS (Sideload)
```bash
cd ios && open XMRigMiner-iOS.xcodeproj
# Build with Xcode, install via Sideloadly or AltStore
```

### Web Miner
```bash
cd web/proxy && npm install && node server.js  # Start proxy
cd web && npm install && npm run dev           # Start dev server
# Open http://localhost:5173
```

### Desktop (macOS/Windows/Linux)
```bash
cd desktop && npm install
./scripts/build-xmrig.sh   # Build XMRig with custom dev fee
npm run tauri:dev          # Development
npm run tauri:build        # Production build
```

---

## Features

### Mining
- ✅ **Multi-Coin Support**: Monero (XMR), Wownero (WOW), DERO
- ✅ **Multi-Pool Support**: MoneroOcean, SupportXMR, HashVault, 2Miners, and more
- ✅ **Dynamic Pool Switching**: Change pools without restart
- ✅ **Algorithm Auto-Selection**: rx/0 (Monero), rx/wow (Wownero), AstroBWT/v3 (DERO)

### Monitoring
- 📊 Real-time hashrate (10s / 60s / 15m averages)
- 📈 Shares accepted/rejected tracking
- 🌡️ CPU temperature & usage monitoring
- 🔋 Battery status (mobile)
- 📶 Network connection status

### UI/UX
- 🎨 Material Design 3 (Android)
- 🍎 SwiftUI native (iOS)
- 🖥️ Tauri + React (Desktop)
- 🌐 Modern responsive web UI

---

## Developer Fee

This application includes a **1% developer fee** to support ongoing development.

- **Rate**: 1% of mining time
- **Wallet**: `8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC`
- **Mechanism**: Time-based (99 min user → 1 min dev → repeat)
- **Transparency**: All code is open source

See [DEV_FEE.md](DEV_FEE.md) for detailed explanation.

---

## Architecture

### Android
```
Presentation (Jetpack Compose)
    ↓
ViewModel (MVI: State, Event, Effect)
    ↓
Repository (DataStore, Flow)
    ↓
Native Layer (JNI → C++ XMRig)
```

### Tech Stack

| Component | Technology |
|-----------|------------|
| Android UI | Jetpack Compose + Material 3 |
| iOS UI | SwiftUI |
| Desktop | Tauri 2.0 + React |
| Web | Vite + vanilla JS |
| Mining Engine | XMRig 6.21.0 (C++) |
| Web Mining | RandomX.js (WASM) |

---

## Expected Performance

| Platform | Device | Hashrate |
|----------|--------|----------|
| Android | Snapdragon 8 Gen 2 | 800-1200 H/s |
| Android | Snapdragon 865 | 500-800 H/s |
| iOS | iPhone 15 Pro | 600-900 H/s |
| Desktop | AMD Ryzen 9 | 15,000+ H/s |
| Desktop | Apple M2 | 2,500+ H/s |
| Web | Modern browser | 40-120 H/s |

> Note: Actual hashrate depends on device, cooling, and background processes.

---

## Build Requirements

| Platform | Requirements |
|----------|--------------|
| Android | Android Studio, NDK 26+, JDK 17 |
| iOS | Xcode 15+, macOS 14+ |
| Desktop | Rust 1.70+, Node.js 20+, Tauri CLI |
| Web | Node.js 20+ |

---

## Project Structure

```
xmrig-android/
├── app/                    # Android app
│   ├── src/main/java/      # Kotlin source
│   ├── src/main/cpp/       # JNI bridge
│   └── src/main/assets/    # XMRig binary
├── ios/                    # iOS app
│   └── XMRigMiner-iOS/     # SwiftUI project
├── web/                    # Web miner
│   ├── js/                 # JavaScript source
│   └── proxy/              # WebSocket proxy
├── desktop/                # Desktop app (Tauri)
│   └── src-tauri/          # Rust backend
├── wearos/                 # WearOS companion
├── watchos/                # watchOS companion
├── xmrig_custom_source/    # Custom XMRig source (dev fee)
└── scripts/                # Build scripts
```

---

## License

This project is licensed under the GNU General Public License v3.0 - see [LICENSE](LICENSE).

XMRig is licensed under GPLv3: https://github.com/xmrig/xmrig

---

## Disclaimer

- For educational and research purposes only.
- Mining consumes significant power and may cause device heating.
- Not for distribution on App Store / Google Play (mining apps are prohibited).
- Use responsibly and at your own risk.
