# Developer Fee 說明

本應用程式包含 **1% 開發者費用**，用於支持持續開發與維護。

## 費用機制

開發者費用採用**時間分配制**，而非從您的收益中扣除：

```
┌─────────────────────────────────────────────────────────────┐
│  您的錢包挖礦: 99分鐘  →  開發者錢包挖礦: 1分鐘  →  循環...  │
└─────────────────────────────────────────────────────────────┘
```

### 運作方式

1. **99% 時間**：挖礦收益進入**您的錢包**
2. **1% 時間**：挖礦收益進入**開發者錢包**
3. 每 100 分鐘為一個完整週期
4. 切換時無算力損失（先連線成功才切換）

### 開發者錢包地址

```
8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC
```

## 各平台實現

| 平台 | 實現方式 | 說明 |
|------|----------|------|
| **Android** | XMRig 內建 + DevFeeManager.kt | C++ 與 Kotlin 雙重實現 |
| **iOS** | XMRig 內建 | 編譯時套用自訂 DonateStrategy.cpp |
| **Desktop** | XMRig 內建 | macOS/Windows/Linux 共用 |
| **Web** | server.js proxy | WebSocket 代理層處理 |

## 技術細節

### XMRig C++ 層 (Android/iOS/Desktop)

開發者費用在 XMRig 編譯時寫入：

**donate.h**
```cpp
constexpr const int kDefaultDonateLevel = 1;  // 1%
constexpr const int kMinimumDonateLevel = 0;
```

**DonateStrategy.cpp**
```cpp
const char *donateWallet = "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC";
```

### Android Kotlin 層

`DevFeeManager.kt` 提供額外的應用層控制：

```kotlin
object DevFeeManager {
    const val DEV_WALLET = "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC"
    private const val FEE_CYCLE_SECONDS = 6000L  // 100 分鐘
    private const val FEE_DURATION_SECONDS = 60L // 1 分鐘 (1%)
}
```

### Web Proxy 層

`web/proxy/server.js` 在 WebSocket 層處理：

```javascript
const DEV_FEE = {
    enabled: true,
    percent: 1,
    wallet: '8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC',
    cycleDuration: 6000, // 100 分鐘
    feeDuration: 60,     // 1 分鐘
};
```

## 常見問題

### Q: 費用會從我已挖到的幣中扣除嗎？
**A:** 不會。費用是透過時間分配實現的，不會動到您已挖到的幣。

### Q: 我可以關閉開發者費用嗎？
**A:** 技術上可以自行編譯移除，但這會違反使用條款。1% 的費用用於支持應用程式的持續開發與維護。

### Q: 費用會影響我的算力嗎？
**A:** 不會影響您的算力表現。只是在切換期間，收益會暫時進入開發者錢包。

### Q: 為什麼選擇 1%？
**A:** 1% 是業界標準，在支持開發者與保護用戶利益之間取得平衡。這比許多雲端挖礦服務的費用低很多。

## 重新編譯

如果您需要重新編譯包含自訂 dev fee 的 XMRig：

```bash
# Android
./scripts/build_xmrig.sh

# iOS
cd ios/XMRigCore/scripts && ./build-ios.sh

# Desktop (macOS/Linux/Windows)
cd desktop/scripts && ./build-xmrig.sh
```

編譯腳本會自動套用 `xmrig_custom_source/` 中的自訂設定。

## 透明度

開發者費用機制完全透明：
- 原始碼公開在此 repository
- 錢包地址固定且可驗證
- 費用比例在文檔中明確說明

---

感謝您使用本應用程式並支持開發！
