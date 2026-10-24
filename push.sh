#!/bin/bash
#
# push.sh - 推送 U-Boot + rkjump 到设备并测试
#
# 前置：先运行 kdev-build.sh 编译，本脚本不负责编译
#
# 用法：
#   ./push.sh           推送 + 跳转
#   ./push.sh go        推送 + 跳转
#   ./push.sh diag      推送 + 诊断（不跳转）
#   ./push.sh probe     推送 + 验证 idmap（不跳转）
#

set -e

DEVICE=192.168.33.39
USER=root
PASS=admin
REMOTE=/hack

UBOOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RKJUMP_DIR="/rockchip/aigo-s60-rk3588.git/6.rockchip-linux-kernel_develop-6.1.git/rkjump"

MODE="${1:-go}"
SSH="sshpass -p $PASS ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $USER@$DEVICE"
SCP="sshpass -p $PASS scp -o StrictHostKeyChecking=no"

# ---- 检查文件 ----
for f in "$UBOOT_DIR/u-boot.bin" "$RKJUMP_DIR/rkjump.ko" "$RKJUMP_DIR/hack.sh"; do
    if [ ! -f "$f" ]; then
        echo "ERR: $f 不存在，请先运行 kdev-build.sh 和编译 rkjump"
        exit 1
    fi
done

# ---- 检查设备 ----
if ! ping -c 1 -W 2 "$DEVICE" >/dev/null 2>&1; then
    echo "ERR: 设备 $DEVICE 不可达，请通过串口 reset 回 Linux"
    exit 1
fi

# ---- 推送 ----
echo "[1/3] 推送文件..."
$SCP "$UBOOT_DIR/u-boot.bin"    "$USER@$DEVICE:$REMOTE/u-boot-current.bin"
$SCP "$RKJUMP_DIR/rkjump.ko"    "$USER@$DEVICE:$REMOTE/rkjump.ko"
$SCP "$RKJUMP_DIR/hack.sh"      "$USER@$DEVICE:$REMOTE/hack.sh"
$SSH "chmod +x $REMOTE/hack.sh"
echo "      payload=$(wc -c < "$UBOOT_DIR/u-boot.bin")B  ko=$(wc -c < "$RKJUMP_DIR/rkjump.ko")B"

# ---- 执行 ----
echo "[2/3] 执行 hack.sh $MODE ..."
if [ "$MODE" = "go" ]; then
    echo "      串口预期: 1 2 3 4 <U-Boot output>"
    echo "      >>> SSH 将断开 <<<"
fi
$SSH "$REMOTE/hack.sh $MODE" 2>&1 || true

# ---- 结果 ----
echo "[3/3] 结果..."
sleep 2
if ping -c 1 -W 2 "$DEVICE" >/dev/null 2>&1; then
    echo "      设备仍在线 — 跳转未执行或已返回"
    $SSH "dmesg | grep RKJUMP | tail -20" 2>/dev/null || true
else
    echo "      设备已离线 — 跳转成功！看串口 U-Boot 输出"
fi
