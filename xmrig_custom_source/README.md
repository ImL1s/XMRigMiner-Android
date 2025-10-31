# Custom XMRig Source Files

這些是已經修改過的 XMRig 源碼檔案，配置了自定義的捐贈機制：

## 修改內容

### 1. src/donate.h
- 設置 `kDefaultDonateLevel = 1` (1%)
- 設置 `kMinimumDonateLevel = 0` (允許用戶選擇 0%)

### 2. src/net/strategies/DonateStrategy.cpp  
- 捐贈礦池: `pool.supportxmr.com:3333`
- 捐贈地址: `85E5c5FcCYJ3UPmebJ1cLENY5siXFTakjTkWperAbZzSJBuwrh3vBBFAxT7xFPp2tCAY4mAs4Qj1gUWBze23pWCES9kgBQu`
- TLS 礦池: `pool.supportxmr.com:5555`

## 如何使用

1. 下載 XMRig 6.21.0 源碼：
   ```bash
   git clone https://github.com/xmrig/xmrig.git
   cd xmrig
   git checkout v6.21.0
   ```

2. 替換修改過的檔案：
   ```bash
   cp donate.h /path/to/xmrig/src/
   cp DonateStrategy.cpp /path/to/xmrig/src/net/strategies/
   ```

3. 按照 BUILDING.md 的說明編譯 XMRig for Android

## 注意事項

- Android 編譯需要 Android NDK 26+
- 需要先編譯 libuv for Android
- 建議禁用 TLS (使用 `-DWITH_TLS=OFF`)
- pthread 和 rt 在 Android 上需要特殊處理

詳細編譯步驟請參考根目錄的 BUILDING.md 文件。
