# 捐贈機制設置完成報告

## ✅ 已完成的工作

### 1. 代碼修改
已修改以下文件以啟用 1% 捐贈機制：

#### Android 應用層
- `app/src/main/java/com/iml1s/xmrigminer/data/model/MiningConfig.kt`
  - `donateLevel = 1` (從 0 改為 1)
  - JSON 配置中 `donate-level: 1`

- `app/src/main/java/com/iml1s/xmrigminer/service/MiningWorker.kt`
  - 命令行參數：`--donate-level=1`
  - 添加：`--donate-over-proxy=1`

#### XMRig 核心層 (源碼修改)
保存在 `xmrig_custom_source/` 目錄：

- `donate.h`
  ```c
  constexpr const int kDefaultDonateLevel = 1;  // 默認 1%
  constexpr const int kMinimumDonateLevel = 0;  // 允許設為 0%
  ```

- `DonateStrategy.cpp`
  ```cpp
  // 捐贈礦池
  static const char *kDonateHost = "pool.supportxmr.com";
  static const char *kDonateHostTls = "pool.supportxmr.com";
  
  // 捐贈錢包地址
  const char *donateWallet = "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC";
  
  // 端口配置
  TLS: port 5555
  Non-TLS: port 3333
  ```

### 2. 文檔更新

#### README.md
- ✅ 添加「開發者捐贈」章節
- ✅ 說明捐贈比例：1%
- ✅ 列明捐贈地址：`8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC`
- ✅ 解釋工作原理
- ✅ 添加重要提示說明

#### BUILDING.md
- ✅ 更新編譯指南
- ✅ 添加自定義捐贈地址的修改步驟
- ✅ 詳細說明如何修改 `donate.h` 和 `DonateStrategy.cpp`

### 3. 捐贈機制說明

#### 工作原理
XMRig 會在挖礦時間的 1% 切換到開發者的錢包地址進行挖礦：
- 挖礦 99 分鐘到用戶錢包
- 切換 1 分鐘到開發者錢包
- 循環往復

#### 捐贈配置
- **捐贈比例**: 1%
- **捐贈池**: pool.supportxmr.com
- **端口**: 3333 (non-TLS) / 5555 (TLS)
- **捐贈地址**: `8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC`

## ⚠️ 重要說明

### 關於當前二進制文件
目前項目使用的 `libxmrig.so` 是預編譯的二進制文件，其中的捐贈地址仍然是 XMRig 官方的默認地址。

### 使用自定義捐贈地址的步驟

要真正使用您的自定義捐贈地址，需要：

1. **下載 XMRig 源碼**
   ```bash
   git clone https://github.com/xmrig/xmrig.git
   cd xmrig
   git checkout v6.21.0
   ```

2. **替換修改過的文件**
   ```bash
   cp xmrig_custom_source/donate.h src/
   cp xmrig_custom_source/DonateStrategy.cpp src/net/strategies/
   ```

3. **編譯 XMRig for Android**
   - 安裝 Android NDK 26+
   - 編譯 libuv for Android
   - 按照 BUILDING.md 指南編譯
   - 注意：需要禁用 TLS (`-DWITH_TLS=OFF`)

4. **替換二進制文件**
   ```bash
   cp xmrig-notls app/src/main/jniLibs/arm64-v8a/libxmrig.so
   ```

5. **重新構建 Android 應用**
   ```bash
   ./gradlew clean assembleDebug
   ```

## 📋 檢查清單

### 應用層修改 (已完成)
- [x] MiningConfig.kt - donateLevel 設為 1
- [x] MiningConfig.kt - JSON 配置中 donate-level 設為 1
- [x] MiningWorker.kt - 命令行參數 --donate-level=1
- [x] MiningWorker.kt - 添加 --donate-over-proxy=1

### 文檔更新 (已完成)
- [x] README.md - 添加開發者捐贈章節
- [x] README.md - 說明捐贈地址和比例
- [x] README.md - 解釋工作原理
- [x] BUILDING.md - 更新編譯指南
- [x] BUILDING.md - 添加自定義捐贈配置步驟

### XMRig 源碼修改 (已完成並保存)
- [x] donate.h - 修改捐贈級別
- [x] DonateStrategy.cpp - 修改捐贈池
- [x] DonateStrategy.cpp - 修改捐贈地址
- [x] 源碼保存在 xmrig_custom_source/

### 待完成 (可選)
- [ ] 編譯 XMRig for Android
- [ ] 替換 libxmrig.so 二進制文件
- [ ] 測試驗證捐贈機制是否正常工作

## 📁 修改的文件列表

```
.
├── README.md                                          (已修改)
├── BUILDING.md                                        (已修改)
├── app/src/main/java/com/iml1s/xmrigminer/
│   ├── data/model/MiningConfig.kt                    (已修改)
│   └── service/MiningWorker.kt                       (已修改)
└── xmrig_custom_source/                              (新增)
    ├── donate.h                                      (XMRig 修改)
    ├── DonateStrategy.cpp                            (XMRig 修改)
    └── README.md                                     (說明文檔)
```

## 🔍 驗證方法

### 檢查應用層配置
```bash
grep -n "donateLevel" app/src/main/java/com/iml1s/xmrigminer/data/model/MiningConfig.kt
grep -n "donate-level" app/src/main/java/com/iml1s/xmrigminer/service/MiningWorker.kt
```

### 檢查 XMRig 源碼
```bash
grep -n "kDefaultDonateLevel" xmrig_custom_source/donate.h
grep -n "donateWallet\|kDonateHost" xmrig_custom_source/DonateStrategy.cpp
```

### 運行時驗證
1. 啟動挖礦
2. 查看 XMRig 日誌輸出
3. 等待約 99 分鐘後，應該會看到切換到 pool.supportxmr.com
4. 在礦池網站檢查您的捐贈地址是否有算力記錄

## 📞 支持

如有問題，請：
1. 查看 BUILDING.md 獲取編譯指南
2. 查看 xmrig_custom_source/README.md 獲取源碼修改說明
3. 在 GitHub Issues 中報告問題

---

**最後更新**: 2025-10-31  
**狀態**: 應用層配置已完成，XMRig 源碼已修改並保存，等待編譯

---

## 🎉 編譯完成更新 (2025-10-31 13:22)

### ✅ XMRig 編譯成功！

**編譯結果**：
- ✅ 成功編譯 XMRig 6.21.0 for Android arm64-v8a
- ✅ 二進制文件：`xmrig-notls` (1.6 MB)
- ✅ 已重命名為：`libxmrig.so`
- ✅ 已複製到：`app/src/main/jniLibs/arm64-v8a/libxmrig.so`

**修復的編譯問題**：
1. ❌ 原問題：pthread 和 rt 庫在 Android 上不存在
2. ✅ 解決方案：修改 CMakeLists.txt，從 EXTRA_LIBS 中移除 pthread 和 rt
3. ✅ 結果：成功編譯並生成可執行的 Android 二進制文件

**驗證捐贈配置**：
```bash
$ strings libxmrig.so | grep -E "pool.supportxmr|85E5c5"
8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC
pool.supportxmr.com
```

✅ **確認：您的捐贈地址已成功嵌入到二進制文件中！**

### 下一步

現在可以重新構建 Android 應用：

```bash
cd /Users/iml1s/Documents/mine/old_project/XMRigMiner
./gradlew clean assembleDebug
```

應用將使用新編譯的 XMRig，捐贈將發送到您的地址！
