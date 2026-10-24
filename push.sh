#!/bin/bash
#
# push.sh - 一键推送 rkjump payload 到设备并跳转
#
# 用法：
#   ./push.sh           编译 + 推送 + 诊断 + 跳转
#   ./push.sh diag      编译 + 推送 + 诊断（不跳转，安全）
#   ./push.sh probe     编译 + 推送 + 验证 idmap（不跳转，安全）
#   ./push.sh go        编译 + 推送 + 跳转（默认）
#   ./push.sh nobuild   跳过编译，只推送 + 跳转
#
# 流程：
#   1. 编译 U-Boot (kdev-build.sh 或 make)
#   2. 推送 u-boot.bin → 设备 /hack/u-boot-current.bin
#   3. 推送 rkjump.ko + hack.sh → 设备 /hack/
#   4. 在设备上运行 hack.sh <mode>
#

set -e

# ---- 配置 ----
DEVICE=192.168.33.39
DEVICE_USER=root
DEVICE_PASS=admin
UBOOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RKJUMP_DIR="/rockchip/aigo-s60-rk3588.git/6.rockchip-linux-kernel_develop-6.1.git/rkjump"
KERNEL_DIR="/rockchip/aigo-s60-rk3588.git/6.rockchip-linux-kernel_develop-6.1.git"
REMOTE_DIR=/hack

# ---- 解析参数 ----
MODE="go"
DO_BUILD=1
for arg in "$@"; do
    case "$arg" in
        go|diag|probe)  MODE="$arg" ;;
        nobuild)        DO_BUILD=0 ;;
        *)  echo "ERR: unknown arg '$arg'"; echo "Usage: $0 [go|diag|probe|nobuild]"; exit 1 ;;
    esac
done

# ---- 辅助函数 ----
SSH="sshpass -p admin ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5"
SCP="sshpass -p admin scp -o StrictHostKeyChecking=no"

log()  { echo -e "\033[1;32m[PUSH]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR]\033[0m $*"; }

# ============================================================
# Step 1: 编译 U-Boot
# ============================================================
if [ "$DO_BUILD" -eq 1 ]; then
    log "Step 1: 编译 U-Boot (TEXT_BASE=0x200000, ENV_IS_NOWHERE)..."
    cd "$UBOOT_DIR"
    export CROSS_COMPILE=aarch64-linux-gnu-
    export RKBIN_DIR="${UBOOT_DIR}/rkbin/bin/rk35"
    export BL31="${UBOOT_DIR}/rkbin/bin/rk35/rk3588_bl31_v1.54.elf"
    export ROCKCHIP_TPL="${UBOOT_DIR}/rkbin/bin/rk35/rk3588_ddr_lp4_1800MHz_lp5_2400MHz_v1.21.bin"

    make mrproper 2>&1 | tail -1
    make aigo-s60-rk3588_defconfig 2>&1 | tail -1
    make -j"$(nproc)" 2>&1 | tail -3

    # 验证入口地址
    ENTRY=$(aarch64-linux-gnu-readelf -h u-boot | grep "Entry point" | awk '{print $4}')
    HEAD=$(xxd -l 4 -p u-boot.bin)
    SIZE=$(wc -c < u-boot.bin)
    log "  u-boot.bin: entry=0x$ENTRY head=$HEAD size=${SIZE}B"
    if [ "$ENTRY" != "0x200000" ]; then
        err "入口地址不是 0x200000! 当前: $ENTRY"
        err "检查 CONFIG_TEXT_BASE in configs/aigo-s60-rk3588_defconfig"
        exit 1
    fi
    if [ "$HEAD" != "0a000014" ]; then
        err "头4字节不是 0a000014! 当前: $HEAD"
        err "可能不是 raw u-boot.bin"
        exit 1
    fi
    log "  编译验证通过 ✓"
else
    log "Step 1: 跳过编译 (nobuild)"
    cd "$UBOOT_DIR"
fi

# ============================================================
# Step 2: 编译 rkjump 内核模块
# ============================================================
if [ "$DO_BUILD" -eq 1 ]; then
    log "Step 2: 编译 rkjump.ko..."
    cd "$RKJUMP_DIR"
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
        KCFLAGS="-Wno-unused-function -Wno-missing-prototypes -Wno-incompatible-pointer-types" \
        -C "$KERNEL_DIR" M="$(pwd)" clean 2>&1 | tail -1
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
        KCFLAGS="-Wno-unused-function -Wno-missing-prototypes -Wno-incompatible-pointer-types" \
        -C "$KERNEL_DIR" M="$(pwd)" modules 2>&1 | tail -3

    # patch vermagic: 6.1.172-kdev → 6.1.75
    python3 -c "
import sys
with open('rkjump.ko', 'rb') as f:
    data = f.read()
old = b'vermagic=6.1.172-kdev SMP mod_unload aarch64'
new = b'vermagic=6.1.75 SMP mod_unload aarch64'
new = new + b'\x00' * (len(old) - len(new))
if old not in data:
    print('WARN: vermagic string not found, may already be patched')
else:
    data = data.replace(old, new)
    with open('rkjump.ko', 'wb') as f:
        f.write(data)
    print('vermagic patched: 6.1.172-kdev → 6.1.75')
"
    log "  rkjump.ko 编译完成 ✓"
else
    log "Step 2: 跳过编译 (nobuild)"
fi

# ============================================================
# Step 3: 检查设备在线
# ============================================================
log "Step 3: 检查设备 $DEVICE ..."
if ! ping -c 1 -W 2 "$DEVICE" >/dev/null 2>&1; then
    err "设备 $DEVICE 不可达！"
    err "请确认设备已启动到 Linux，或通过串口重启。"
    exit 1
fi
log "  设备在线 ✓"

# ============================================================
# Step 4: 推送文件到设备
# ============================================================
log "Step 4: 推送文件到 $DEVICE:$REMOTE_DIR/ ..."

# 推送 u-boot.bin → u-boot-current.bin (rkjump payload)
$SCP "$UBOOT_DIR/u-boot.bin" \
    "$DEVICE_USER@$DEVICE:$REMOTE_DIR/u-boot-current.bin" 2>&1
log "  u-boot.bin → u-boot-current.bin ($(wc -c < "$UBOOT_DIR/u-boot.bin")B) ✓"

# 推送 rkjump.ko
$SCP "$RKJUMP_DIR/rkjump.ko" \
    "$DEVICE_USER@$DEVICE:$REMOTE_DIR/rkjump.ko" 2>&1
log "  rkjump.ko ✓"

# 推送 hack.sh
$SCP "$RKJUMP_DIR/hack.sh" \
    "$DEVICE_USER@$DEVICE:$REMOTE_DIR/hack.sh" 2>&1
log "  hack.sh ✓"

# 设置权限
$SSH "$DEVICE_USER@$DEVICE" "chmod +x $REMOTE_DIR/hack.sh" 2>&1

# 验证设备上文件
log "  设备文件验证:"
$SSH "$DEVICE_USER@$DEVICE" "echo '  payload:' && od -A x -t x1 -N 4 $REMOTE_DIR/u-boot-current.bin && echo '  ko:'      && ls -la $REMOTE_DIR/rkjump.ko && echo '  script:'  && ls -la $REMOTE_DIR/hack.sh" 2>&1 | grep -E "payload|ko:|script:|000000|rkjump|hack"

# ============================================================
# Step 5: 执行
# ============================================================
log "Step 5: 执行 hack.sh $MODE ..."
log "  串口预期 (go): 1 2 3 4 <U-Boot output>"

case "$MODE" in
    diag|probe)
        $SSH "$DEVICE_USER@$DEVICE" "$REMOTE_DIR/hack.sh $MODE" 2>&1
        log "完成 ($MODE)。查看 dmesg: $SSH $DEVICE_USER@$DEVICE dmesg | grep RKJUMP"
        ;;
    go)
        log "  >>> 3秒后不可逆跳转，SSH 将断开 <<<"
        $SSH "$DEVICE_USER@$DEVICE" "$REMOTE_DIR/hack.sh go" 2>&1 || true
        sleep 2
        if ping -c 1 -W 2 "$DEVICE" >/dev/null 2>&1; then
            log "设备仍在线 — 跳转可能未执行或已返回 Linux"
        else
            log "设备已离线 — 跳转成功！检查串口看 U-Boot 输出"
        fi
        ;;
esac

