# XMRig Miner (Android + Web)

[![Android CI/CD](https://github.com/ImL1s/xmrig-android/actions/workflows/release.yml/badge.svg)](https://github.com/ImL1s/xmrig-android/actions/workflows/release.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**跨平台** Monero (XMR) 挖礦方案：
- **📱 Android 應用**: 基於 XMRig 6.21.0 的原生 Android 礦機，Material Design 3 介面。
- **🌐 網頁礦機 (New!)**: 基於 RandomX.js (WebAssembly) 的瀏覽器礦機，支援任何平台。

[English](README.md)

## 📱 功能特性

### 核心功能
- ✅ **完整的 XMRig 集成** - 基於 XMRig 6.21.0，支持 RandomX 算法
- 🎯 **原生性能優化** - 使用 C++ NDK 編譯，針對 ARMv8 (64-bit) 優化
- 📊 **實時監控** - 實時顯示算力、難度、CPU 使用率、溫度等
- 🔧 **靈活配置** - 完整的礦池配置、線程管理、性能調優選項
- 🌐 **多礦池支持** - 支持主流 Monero 礦池（SupportXMR、MoneroOcean 等）
- 💾 **配置持久化** - 使用 DataStore 保存用戶配置

### 監控功能
- **算力監控**
  - 10秒/60秒/15分鐘平均算力
  - 峰值算力記錄
  - 實時算力曲線圖
  
- **系統監控**
  - CPU 使用率（嘗試讀取 /proc/stat，Android 11+ 可能受限）
  - 設備溫度監控
  - 電池狀態和充電狀態
  - 網絡連接狀態

- **挖礦狀態**
  - 已接受/拒絕的份額數
  - 當前難度值
  - 礦池連接狀態
  - XMRig 日誌輸出

### 安全特性
- 🔒 **開發者捐贈** - donate-level = 1% 用於支持開發者
- 🔐 **隱私保護** - 不收集任何用戶數據
- 🛡️ **開源透明** - 完整源代碼公開

---

## 🌐 網頁礦機 (New!)

直接在瀏覽器中挖礦 Monero - 無需安裝任何軟體！

### 功能特點
- **純 JavaScript + WebAssembly** - 使用 `randomx.js` 實現接近原生的效能
- **多礦池支援** - MoneroOcean, SupportXMR, HashVault, 2Miners
- **動態礦池切換** - 無需重啟即可切換礦池
- **即時統計** - 算力、份額、運行時間即時顯示

### 快速開始 (網頁礦機)
```bash
# 1. 啟動 WebSocket-to-Stratum 代理
cd web/proxy && node server.js

# 2. 啟動 Vite 開發伺服器
cd web && npm run dev

# 3. 開啟 http://localhost:5173
```

### 預期效能
- **桌面瀏覽器**: ~40-80 H/s (依 CPU 而定)
- **行動瀏覽器**: ~10-30 H/s

> ⚠️ **注意**: 網頁挖礦的算力比原生應用低，因瀏覽器沙箱限制所致。

---

### 開發者捐贈
本應用設置了 1% 的捐贈級別，用於支持開發者持續維護和改進此項目。
- **捐贈比例**: 1%
- **捐贈地址**: 8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC
- **透明度**: 所有捐贈設置均在源代碼中公開可見
- **工作原理**: XMRig 會在挖礦時間的 1% 切換到開發者的錢包地址進行挖礦

> **注意**: 由於 XMRig 的捐贈地址是在編譯時硬編碼到二進制文件中的，如需使用自定義捐贈地址，需要重新編譯 XMRig。當前使用的是 XMRig 官方默認的捐贈地址。如果您想支持本項目開發者，可以直接向上述地址捐贈 XMR。

## 🏗️ 技術架構

### 技術棧
- **語言**: Kotlin 1.9.20
- **UI 框架**: Jetpack Compose (Material Design 3)
- **架構模式**: MVVM + Clean Architecture
- **依賴注入**: Hilt (Dagger)
- **異步處理**: Kotlin Coroutines + Flow
- **數據持久化**: DataStore (Preferences) + Room
- **後台任務**: WorkManager
- **Native 層**: C++ (XMRig 6.21.0)
- **構建工具**: Gradle 8.2.0 + AGP 8.2.0

### 項目結構
```
app/
├── src/
│   ├── main/
│   │   ├── java/com/iml1s/xmrigminer/
│   │   │   ├── data/              # 數據層
│   │   │   │   ├── model/         # 數據模型
│   │   │   │   └── repository/    # 數據倉庫
│   │   │   ├── domain/            # 業務邏輯層
│   │   │   ├── presentation/      # 展示層
│   │   │   │   ├── config/        # 配置界面
│   │   │   │   ├── mining/        # 挖礦界面
│   │   │   │   └── stats/         # 統計界面
│   │   │   ├── service/           # 後台服務
│   │   │   │   ├── MiningWorker.kt    # 挖礦 Worker
│   │   │   │   └── MonitorWorker.kt   # 監控 Worker
│   │   │   ├── native/            # JNI 橋接
│   │   │   └── di/                # 依賴注入
│   │   ├── cpp/                   # C++ 原生代碼
│   │   │   └── native-bridge.cpp  # XMRig 橋接層
│   │   └── res/                   # 資源文件
│   └── xmrig/                     # XMRig 源碼
│       └── libs/                  # 預編譯 XMRig 庫
└── build.gradle.kts
```

### 架構層次
```
┌─────────────────────────────────┐
│     Presentation Layer          │
│   (Jetpack Compose UI)          │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│      ViewModel Layer             │
│   (State Management)             │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│      Domain Layer                │
│   (Business Logic)               │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│       Data Layer                 │
│  (Repository + DataStore)        │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│    Service Layer                 │
│  (WorkManager + XMRig)           │
└──────────────────────────────────┘
```

## 🚀 快速開始

### 環境要求
- Android Studio Hedgehog (2023.1.1) 或更高版本
- Android SDK 34
- NDK 26.1.10909125
- CMake 3.22.1
- JDK 17
- Gradle 8.2+

### 編譯步驟

1. **克隆項目**
```bash
git clone https://github.com/ImL1s/XMRigMiner-Android.git
cd XMRigMiner-Android
```

2. **配置 NDK**
確保在 `local.properties` 中配置了 NDK 路徑：
```properties
ndk.dir=/Users/<username>/Library/Android/sdk/ndk/26.3.11579264
```

3. **同步依賴**
```bash
./gradlew clean build
```

4. **編譯 APK**
```bash
# Debug 版本
./gradlew assembleDebug

# Release 版本
./gradlew assembleRelease
```

### 運行應用

1. 連接 Android 設備或啟動模擬器（推薦真機，模擬器性能較差）
2. 在 Android Studio 中點擊 Run 按鈕
3. 或使用命令行：
```bash
./gradlew installDebug
```

## 📱 使用說明

### 首次配置

1. **錢包配置**
   - 輸入你的 Monero 錢包地址
   - 選擇礦池（默認：pool.supportxmr.com:3333）
   - 設置礦工名稱（可選）

2. **性能調優**
   - **線程數**: 默認為 CPU 核心數 - 1，建議保持默認
   - **最大 CPU 使用率**: 建議設置為 75% 以避免過熱
   - **TLS 加密**: 建議啟用以保護連接安全

3. **高級選項**
   - 自動重連：網絡斷開時自動重連
   - 鎖屏挖礦：屏幕關閉時繼續挖礦（需注意電池消耗）
   - 重試次數和間隔：連接失敗時的重試策略

### 開始挖礦

1. 點擊「開始挖礦」按鈕
2. 應用會在後台啟動 XMRig 進程
3. 實時監控面板會顯示：
   - 當前算力（10s/60s/15m 平均值）
   - 已接受份額數
   - 難度值
   - CPU 使用率（如果可用）
   - 設備溫度
   - 電池狀態

### 停止挖礦

點擊「停止挖礦」按鈕，應用會安全地終止挖礦進程。

## ⚙️ 配置說明

### 礦池配置

#### SupportXMR (推薦)
```
URL: pool.supportxmr.com:3333
TLS: 建議啟用
最低支付: 0.1 XMR
```

#### MoneroOcean
```
URL: gulf.moneroocean.stream:10128
TLS: 建議啟用
智能挖礦: 自動切換最有利的幣種
```

### 性能優化建議

1. **設備選擇**
   - 推薦使用高端 Android 設備（驍龍 8 系列、天璣 9000+ 等）
   - 至少 4GB RAM
   - 良好的散熱設計

2. **環境設置**
   - 確保設備處於充電狀態
   - 保持良好的散熱環境
   - 避免長時間連續挖礦（建議每 2-3 小時休息一次）

3. **參數調優**
   - CPU 使用率：60-75% 之間較為平衡
   - 線程數：不建議使用所有核心
   - 溫度監控：超過 40°C 建議降低線程數或停止挖礦

## 📊 性能數據

基於實際測試數據（日誌記錄）：

### 測試設備
- CPU: ARM Cortex-A55 (8 cores)
- RAM: 5.5 GB
- 溫度: 30-38°C

### 算力表現
- **平均算力**: 250-350 H/s
- **峰值算力**: 348 H/s
- **穩定性**: 良好（10s/60s/15m 波動較小）

### 資源佔用
- **線程數**: 5 個挖礦線程
- **內存使用**: 約 2.3 GB (RandomX dataset)
- **Huge Pages**: 0% (Android 限制)

## 🔧 已知問題

### CPU 使用率監控失敗
```
Error: EACCES (Permission denied) reading /proc/stat
```
**原因**: Android 11+ 限制了對 `/proc/stat` 的訪問  
**狀態**: 已實現，但在新版 Android 上可能無法工作  
**替代方案**: 可以通過 XMRig 輸出間接判斷 CPU 負載

### 文件權限問題
早期版本在 `files/` 目錄下無法執行二進制文件。
**解決方案**: 已改為將 XMRig 編譯為 `.so` 庫並加載到 `lib/` 目錄

### XMRig 配置未加載
XMRig 默認會嘗試從多個位置讀取配置文件。
**解決方案**: 在運行時動態生成 `config.json` 並通過命令行參數傳遞

## 🔒 隱私和安全

### 我們不會
- ❌ 收集任何用戶數據
- ❌ 上傳挖礦統計到第三方服務器
- ❌ 包含任何追蹤或分析 SDK
- ❌ 要求不必要的權限

### 我們會
- ✅ 設置 donate-level = 1% 支持開發
- ✅ 開源所有代碼
- ✅ 使用本地 DataStore 保存配置
- ✅ 僅請求必要權限（網絡、前台服務、WakeLock）

### 權限說明
```xml
<!-- 網絡連接 - 連接礦池必需 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- 前台服務 - 保持挖礦進程運行 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

<!-- WakeLock - 保持 CPU 運行 -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- 電池信息 - 顯示充電狀態 -->
<uses-permission android:name="android.permission.BATTERY_STATS" />
```

## 🐛 問題排查

### 挖礦無法啟動

1. 檢查錢包地址是否正確
2. 確認網絡連接正常
3. 查看日誌輸出：
```
Logcat 過濾器: tag:MiningWorker OR tag:XMRig
```

### 算力過低

1. 降低 CPU 使用率限制
2. 增加線程數
3. 確保設備沒有過熱降頻
4. 檢查是否有其他後台應用佔用 CPU

### 頻繁斷線

1. 檢查網絡穩定性
2. 嘗試更換礦池
3. 啟用自動重連功能
4. 增加重試次數和間隔

### 應用崩潰

1. 檢查設備 RAM 是否充足（建議至少 4GB）
2. 清除應用數據並重新配置
3. 查看崩潰日誌並提交 Issue

## 🛠️ 開發指南

### 添加新功能

1. **數據模型**：在 `data/model/` 中定義
2. **倉庫層**：在 `data/repository/` 中實現數據訪問
3. **UI 狀態**：在對應的 `Contract.kt` 中定義
4. **ViewModel**：處理業務邏輯和狀態管理
5. **Composable**：在 `Screen.kt` 中實現 UI

### 修改 XMRig 配置

編輯 `MiningConfig.kt` 中的 `toJson()` 方法：
```kotlin
fun toJson(): String {
    return """
    {
        // 在這裡添加或修改 XMRig 配置項
    }
    """.trimIndent()
}
```

### 添加新的監控指標

1. 在 `MiningWorker.kt` 中添加監控邏輯
2. 更新 `MiningState` 數據類
3. 在 UI 中顯示新指標

## 📄 License

本項目採用 GNU General Public License v3.0，請參閱 [LICENSE](LICENSE) 文件。

### XMRig License
XMRig 採用 GPLv3 許可證，詳見：https://github.com/xmrig/xmrig

## 🙏 致謝

- [XMRig](https://github.com/xmrig/xmrig) - 強大的 Monero 挖礦引擎
- [Jetpack Compose](https://developer.android.com/jetpack/compose) - 現代化的 Android UI 工具包
- [Hilt](https://developer.android.com/training/dependency-injection/hilt-android) - 正式的 Android 依賴注入框架

## 🔍 代碼安全檢查

本項目已經過安全檢查，確認：
- ✅ 無硬編碼的錢包地址
- ✅ 無 API 密鑰或 Token
- ✅ 無第三方追蹤代碼
- ✅ 僅包含默認的礦池地址作為示例（用戶可自行配置）

## 📮 聯繫方式

- **Issues**: 請在 GitHub Issues 中報告問題
- **Pull Requests**: 歡迎提交 PR 改進項目

## ⚠️ 免責聲明

- 本應用僅供學習和研究使用
- 長時間挖礦可能導致設備過熱和電池損耗
- 請確保在允許的情況下使用本應用
- 挖礦收益受多種因素影響，不保證盈利
- 使用本應用的一切後果由用戶自行承擔

## 📝 更新日誌

### v1.0.1 (2026-01-03)
- ✨ 核心功能優化與多語系支援
- ✅ 完整的 XMRig 6.21.0 集成
- ✅ 自動化 CI/CD 發布流程 (GitHub Actions)
- ✅ 授權變更為 GPLv3
- ✅ 修正新版 Android CPU 監控說明
- ✅ Material Design 3 UI
- ✅ 實時算力和系統監控
- ✅ 完整的配置管理
- ✅ WorkManager 後台任務
- ✅ DataStore 配置持久化

---

**注意**: 這是一個開源項目，我們不對任何使用本應用造成的損失負責。請合理使用，注意設備健康。
