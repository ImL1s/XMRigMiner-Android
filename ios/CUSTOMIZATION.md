# iOS XMRigMiner Customization Record

這份文件記錄了為滿足特定需求而對原始碼進行的客製化修改。

## 1. 錢包地址 (Wallet Address)
- **Address**: `8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC`
- **位置**: 
  - `ios/XMRigMiner-iOS/Sources/Models/MiningConfig.swift` (預設配置)
  - `ios/XMRigCore/src/net/strategies/DonateStrategy.cpp` (核心抽成重定向)

## 2. 核心抽成重定向 (Fee/Donate Redirection)
為了確保所有算力（包含原本捐贈給開發者的部分）都歸屬於使用者，我們修改了 XMRig 核心庫：

- **File**: `ios/XMRigCore/src/net/strategies/DonateStrategy.cpp`
- **Modification**:
  - 強制設定 `m_userId` 為上述使用者錢包地址。
  - 將 `kDonateHost` (捐贈礦池) 強制指向 `pool.supportxmr.com` (標準礦池)。
  - **效果**: 當 XMRig 進入 "Donate" 模式時，實際上是使用您的錢包在您的礦池挖礦。

## 3. 自動駕駛 (Auto-Pilot)
為了方便無人值守操作與測試：

- **File**: `ios/XMRigMiner-iOS/Sources/App/ContentView.swift`
- **Feature**: 
  - **Auto-Mine**: App 啟動後 3 秒自動開始挖礦。
  - **Auto-Log**: 挖礦開始後 5 秒自動切換至 Log 分頁，展示即時數據。

## 4. 編譯資訊
- **Static Library**: `libxmrig-ios-arm64.a` 已使用上述修改重新編譯。
- **Xcode Project**: 已設定自動連結此客製化核心。
