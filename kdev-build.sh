#!/usr/bin/bash

set -xe

WORKDIR=`pwd`
DEFCONFIG="bdy-g98-rk3588_defconfig"
JOBS=$(nproc)

cd "$WORKDIR"
export CROSS_COMPILE=aarch64-linux-gnu-
export RKBIN_DIR="${WORKDIR}/rkbin/bin/rk35"
export BL31="${WORKDIR}/rkbin/bin/rk35/rk3588_bl31_v1.54.elf"
export ROCKCHIP_TPL="${WORKDIR}/rkbin/bin/rk35/rk3588_ddr_lp4_1800MHz_lp5_2400MHz_v1.21.bin"
# export TEE="${WORKDIR}/rkbin/bin/rk35/rk3588_bl32_v1.20.bin"

ls -alh ${BL31}
ls -alh ${ROCKCHIP_TPL}
sha256sum ${BL31}
sha256sum ${ROCKCHIP_TPL}

# only-spi
cp -a only-spi/spl.c                     common/spl/spl.c
cp -a only-spi/rk3588-bdy-g98.dts        dts/upstream/src/arm64/rockchip/rk3588-bdy-g98.dts
cp -a only-spi/bdy-g98-rk3588_defconfig  configs/bdy-g98-rk3588_defconfig

cd "$WORKDIR"
make mrproper
make "$DEFCONFIG"
make -j"$JOBS"

rm -rf output
mkdir -p output
cp -a u-boot-rockchip-spi.bin \
	u-boot-rockchip.bin \
	idbloader.img \
	u-boot.itb \
	u-boot.bin \
	u-boot.img \
	output/

dtc -I dtb -O dts  ./dts/upstream/src/arm64/rockchip/rk3588-bdy-g98.dtb -o rk3588-bdy-g98.dts

ls -alh output/
ls -alh   dts/upstream/src/arm64/rockchip/rk3588-bdy-g98.dts
ls -alh   configs/bdy-g98-rk3588_defconfig

echo "All done!"
