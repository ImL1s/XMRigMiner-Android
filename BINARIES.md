# XMRig Binary Compilation Guide

[繁體中文](BINARIES_zh-TW.md)

## 📦 Binary Options

This project supports three ways to get XMRig binaries:

### Option A: Compile Yourself (Recommended) ⭐⭐⭐⭐⭐

**Security**: Best (full control)  
**Time**: 2-4 hours  
**Requirements**: Android NDK + CMake

```bash
cd XMRigMiner
./scripts/compile_xmrig.sh
```

See [BUILDING.md](BUILDING.md) for detailed steps.

### Option B: Use Mock Binaries (Testing) ⭐⭐⭐

**Security**: Safe (no actual mining)  
**Time**: Instant  
**Purpose**: Test app flow

```bash
cd XMRigMiner
./scripts/create_mock_binaries.sh
```

**Features**:
- ✅ Simulates XMRig output
- ✅ Tests UI updates
- ✅ Tests monitoring system
- ❌ Does NOT actually mine

### Option C: Download Pre-built (Use with Caution) ⚠️

**Security**: Depends on source trust  
**Time**: 5 minutes  
**Risk**: Potential backdoors

**We do NOT provide pre-built binaries.**

If you find them elsewhere:
1. Verify SHA256 checksum
2. Scan with antivirus
3. Review with `strings` command
4. Use at your own risk

---

## 🔍 Verification

After obtaining binaries, verify:

```bash
# Check file type
file app/src/main/assets/xmrig_*

# Expected output:
# xmrig_arm64_v8a:     ELF 64-bit LSB executable, ARM aarch64
# xmrig_armeabi_v7a:   ELF 32-bit LSB executable, ARM, EABI5

# Check size (should be 2-5 MB for real, <1KB for mock)
ls -lh app/src/main/assets/xmrig_*

# Test execution (on device)
adb shell run-as com.iml1s.xmrigminer.debug ./files/xmrig --version
```

---

## 📋 Current Status

| Binary | Status | Type | Size |
|--------|--------|------|------|
| xmrig_arm64_v8a | ✅ | Real/Mock | 2-5 MB / <1KB |
| xmrig_armeabi_v7a | ✅ | Real/Mock | 2-5 MB / <1KB |

**Note**: The release v1.0.1+ on GitHub includes real binaries. The source code uses mock binaries by default for testing.

**To upgrade to real binaries:**
```bash
./scripts/compile_xmrig.sh
```

---

## ⚠️ Important Notes

### Mock Binaries
- ✅ Safe for development
- ✅ Test UI/monitoring
- ✅ Validate app flow
- ❌ **Cannot mine** (no actual computation)

### Real Binaries
- ⚠️ Compile yourself (best security)
- ⚠️ Verify source code (check donate.h)
- ⚠️ Use trusted NDK
- ⚠️ Check final binaries

---

## 🛡️ Security Checklist

Before using ANY XMRig binary:

- [ ] Compiled yourself OR
- [ ] From 100% trusted source
- [ ] Verified SHA256 checksum
- [ ] Checked with `strings` for suspicious domains
- [ ] Scanned with antivirus
- [ ] Tested in isolated environment first
- [ ] Reviewed donate.h was modified (0%)

---

## 📚 Additional Resources

- [Official XMRig](https://github.com/xmrig/xmrig)
- [BUILDING.md](BUILDING.md) - Full compilation guide
- [Android NDK Guide](https://developer.android.com/ndk)

---

**Last Updated**: 2025-10-30  
**Binary Status**: Mock (for testing)  
**Recommendation**: Compile yourself for production use
