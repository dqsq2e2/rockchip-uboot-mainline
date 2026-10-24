#!/usr/bin/bash

set -xe

WORKDIR=`pwd`
DEFCONFIG="aigo-s60-rk3588_defconfig"
JOBS=$(nproc)
TIMESTAMP=$(date +%Y%m%d)

cd "$WORKDIR"
export CROSS_COMPILE=aarch64-linux-gnu-
export RKBIN_DIR="${WORKDIR}/rkbin/bin/rk35"
export BL31="${WORKDIR}/rkbin/bin/rk35/rk3588_bl31_v1.54.elf"
export ROCKCHIP_TPL="${WORKDIR}/rkbin/bin/rk35/rk3588_ddr_lp4_1800MHz_lp5_2400MHz_v1.21.bin"

ls -alh ${BL31}
ls -alh ${ROCKCHIP_TPL}
sha256sum ${BL31}
sha256sum ${ROCKCHIP_TPL}

ls -alh  dts/upstream/src/arm64/rockchip/rk3588-aigo-s60.dts
ls -alh  configs/aigo-s60-rk3588_defconfig

#cd "$WORKDIR"
#rm -rf output
#mkdir -p output
#cd rkbin
#./tools/boot_merger `pwd`/RKBOOT/RK3588MINIALL.ini
#cp -a rk3588_spl_loader_v1.21.114.bin ${WORKDIR}/output/rk3588_spl_loader_v1.21.114.bin
#cp -a rk3588_spl_loader_v1.21.114.bin ${WORKDIR}/output/rk3588_spl_loader_v1.21.114_${TIMESTAMP}.bin

cd "$WORKDIR"
make mrproper
make "$DEFCONFIG"
make -j"$JOBS"

cd "$WORKDIR"
rm -rf output
mkdir -p output
#dd if=u-boot-rockchip.bin of=${WORKDIR}/output/uboot.img bs=512 skip=64
#dd if=u-boot-rockchip.bin of=${WORKDIR}/output/uboot-aigo-s60.img bs=512 skip=64
#dd if=u-boot-rockchip.bin of=${WORKDIR}/output/uboot-aigo-s60_${TIMESTAMP}.img bs=512 skip=64

# ---- rkjump payload ----
# rkjump 需要裸 U-Boot 二进制 (u-boot.bin)，不是 u-boot-rockchip.bin
# u-boot-rockchip.bin 是完整 flash 镜像 (RKNS header + SPL + FIT)，链接在 0x00000000
# rkjump 把文件写到 PA 0x200000 然后跳 offset 0 执行
#   → 必须用 u-boot.bin (链接在 0x200000 = CONFIG_TEXT_BASE)
#   → 不能用 u-boot-rockchip.bin (offset 0 是 SPL，链接在 0x00000000)
cp -f u-boot.bin ${WORKDIR}/output/u-boot-rkjump.bin
cp -f u-boot.bin ${WORKDIR}/output/u-boot-rkjump_${TIMESTAMP}.bin
echo "=== rkjump payload ==="
echo "u-boot.bin entry point:"
${CROSS_COMPILE}readelf -h u-boot | grep "Entry point"
xxd -l 4 u-boot.bin
echo "u-boot.bin size: $(wc -c < u-boot.bin) bytes"
echo "→ output/u-boot-rkjump.bin 就是 rkjump 的 payload"

#fdtdump ./dts/upstream/src/arm64/rockchip/rk3588-aigo-s60.dtb > rk3588-aigo-s60.dts
#fdtdump ./spl/dts/dt-spl.dtb > dt-spl.dts

#ls -alh   dts/upstream/src/arm64/rockchip/rk3588-aigo-s60.dts
#ls -alh   configs/aigo-s60-rk3588_defconfig
ls -alh   output/

echo "All done!"
