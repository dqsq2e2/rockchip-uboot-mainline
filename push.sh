#!/bin/bash
#
# push.sh - 推送 U-Boot + rkjump 到设备并测试
#
# 用法：
#   ./push.sh           推送 + 跳转
#   ./push.sh go        同上
#   ./push.sh diag      推送 + 诊断（不跳转）
#   ./push.sh probe     推送 + 验证 idmap（不跳转）
#

set -e

DEVICE=192.168.33.39
USER=root
PASS=admin
REMOTE=/recovery/rkjump/

UBOOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RKJUMP_DIR="/rockchip/aigo-s60-rk3588.git/6.rockchip-linux-kernel_develop-6.1.git/rkjump"

# 解析参数
MODE=""
for arg in "$@"; do
    case "$arg" in
        go|diag|probe) MODE="$arg" ;;
        *) echo "ERR: unknown arg '$arg'"; exit 1 ;;
    esac
done
MODE="${MODE:-go}"

SSH="sshpass -p $PASS ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $USER@$DEVICE"
SCP="sshpass -p $PASS scp -o StrictHostKeyChecking=no"

echo "[1/2] 推送文件..."
$SCP "$UBOOT_DIR/u-boot.bin"    "$USER@$DEVICE:$REMOTE/u-boot-current.bin"
$SCP "$RKJUMP_DIR/rkjump.ko"    "$USER@$DEVICE:$REMOTE/rkjump.ko"
$SCP "$RKJUMP_DIR/hack.sh"      "$USER@$DEVICE:$REMOTE/hack.sh"
$SSH "chmod +x $REMOTE/hack.sh"

echo "      payload=$(wc -c < "$UBOOT_DIR/u-boot.bin")B  ko=$(wc -c < "$RKJUMP_DIR/rkjump.ko")B"

echo "[2/2] 执行 hack.sh $MODE ..."
if [ "$MODE" = "go" ]; then
    echo "      串口预期: 1 2 3 4 <U-Boot output>"
    echo "      >>> SSH 将断开 <<<"
fi
$SSH "$REMOTE/hack.sh $MODE" 2>&1 || true

