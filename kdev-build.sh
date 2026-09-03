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

cd "$WORKDIR"
make distclean
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

ls -alh output/

echo "All done!"
