# XMRig 二進制文件編譯指南

## 📦 二進制選項

本專案支援三種獲取 XMRig 二進制文件的方式：

### 選項 A：自行編譯（推薦） ⭐⭐⭐⭐⭐

**安全性**：最高（完全控制）  
**時間**：2-4 小時  
**要求**：Android NDK + CMake

```bash
cd XMRigMiner
./scripts/compile_xmrig.sh
```

詳細步驟請參閱 [BUILDING_zh-TW.md](BUILDING_zh-TW.md)。

### 選項 B：使用 Mock 二進制文件（測試用） ⭐⭐⭐

**安全性**：安全（無實際挖礦行為）  
**時間**：即時  
**目的**：測試應用流程

```bash
cd XMRigMiner
./scripts/create_mock_binaries.sh
```

**特性**：
- ✅ 模擬 XMRig 輸出
- ✅ 測試 UI 更新
- ✅ 測試監控系統
- ❌ **不會**實際挖礦

### 選項 C：下載預編譯版本（謹慎使用） ⚠️

**安全性**：取決於來源信任度  
**時間**：5 分鐘  
**風險**：可能包含後門

**我們不提供預編譯的二進制文件。**

如果您從其他地方獲取：
1. 驗證 SHA256 校驗和
2. 使用防毒軟體掃描
3. 使用 `strings` 命令審查
4. 使用風險自負

---

## 🔍 驗證

獲取二進制文件後，請驗證：

```bash
# 檢查文件類型
file app/src/main/assets/xmrig_*

# 預期輸出：
# xmrig_arm64_v8a:     ELF 64-bit LSB executable, ARM aarch64
# xmrig_armeabi_v7a:   ELF 32-bit LSB executable, ARM, EABI5

# 檢查大小（真實文件約 2-5 MB，Mock 文件 <1KB）
ls -lh app/src/main/assets/xmrig_*
```

---

## 📋 當前狀態

| 文件 | 狀態 | 類型 | 大小 |
|--------|--------|------|------|
| xmrig_arm64_v8a | ✅ | 真實/Mock | 2-5 MB / <1KB |
| xmrig_armeabi_v7a | ✅ | 真實/Mock | 2-5 MB / <1KB |

**注意**：GitHub 上的 v1.0.1+ 版本包含真實的二進制文件。源代碼默認使用 Mock 文件進行開發測試。

詳細步驟請參閱 [BUILDING_zh-TW.md](BUILDING_zh-TW.md)。

---

**最後更新**: 2026-01-03
