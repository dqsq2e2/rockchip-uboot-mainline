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
rm -rf output
mkdir -p output
cd rkbin
./tools/boot_merger `pwd`/RKBOOT/RK3588MINIALL.ini
mv rk3588_spl_loader_v1.21.114.bin ${WORKDIR}/output/

cd "$WORKDIR"
make mrproper
make "$DEFCONFIG"
make -j"$JOBS"

dd if=u-boot-rockchip-spi.bin of=${WORKDIR}/output/uboot-only-spi.img bs=512 skip=64

# only-emmc

#dtc -I dtb -O dts  ./dts/upstream/src/arm64/rockchip/rk3588-bdy-g98.dtb -o rk3588-bdy-g98.dts
fdtdump ./dts/upstream/src/arm64/rockchip/rk3588-bdy-g98.dtb > rk3588-bdy-g98.dts
fdtdump ./spl/dts/dt-spl.dtb > dt-spl.dts

ls -alh   output/
ls -alh   dts/upstream/src/arm64/rockchip/rk3588-bdy-g98.dts
ls -alh   configs/bdy-g98-rk3588_defconfig

echo "All done!"
