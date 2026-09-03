#!/usr/bin/bash


WORK_DIR=`pwd`
DEFCONFIG="bdy-g98-rk3588_defconfig"
#DEFCONFIG="evb-rk3588_defconfig"
JOBS=$(nproc)


cd "$WORK_DIR"
RKBIN_DIR="$WORK_DIR/rkbin/bin/rk35"
TPL_BIN=$(ls -t "$RKBIN_DIR"/rk3588_ddr_*.bin 2>/dev/null | head -1)
if [ -z "$TPL_BIN" ]; then
    echo "ERROR: 未找到 rk3588_ddr_*.bin，请检查 rkbin 仓库"
    exit 1
fi

BL31_BIN=$(ls -t "$RKBIN_DIR"/rk3588_bl31_*.elf 2>/dev/null | head -1)
if [ -z "$BL31_BIN" ]; then
    echo "ERROR: 未找到 rk3588_bl31_*.elf，请检查 rkbin 仓库"
    exit 1
fi

echo "  TPL  : $TPL_BIN"
echo "  BL31 : $BL31_BIN"

cd "$WORK_DIR"
make distclean
export CROSS_COMPILE=aarch64-linux-gnu-
export BL31="$BL31_BIN"
export ROCKCHIP_TPL="$TPL_BIN"

make "$DEFCONFIG"
make -j"$JOBS"

echo ""
echo "========================================="
echo " 编译完成！产物位于: $WORK_DIR"
echo "========================================="
ls -lh idbloader.img u-boot.itb u-boot.bin u-boot.img 2>/dev/null || true
echo ""
echo "关键文件："
echo "  idbloader.img  → 写入 32KB 偏移 (sector 64)"
echo "  u-boot.itb     → 写入 1MB 偏移 (sector 0x800)"
echo ""

rm -rf output
mkdir -p output
cp -a idbloader.img u-boot.itb u-boot.bin u-boot.img output/

echo "All done!"
