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

dd if=u-boot-rockchip.bin of=${WORKDIR}/output/uboot.img bs=512 skip=64
dd if=u-boot-rockchip.bin of=${WORKDIR}/output/uboot-aigo-s60.img bs=512 skip=64
dd if=u-boot-rockchip.bin of=${WORKDIR}/output/uboot-aigo-s60_${TIMESTAMP}.img bs=512 skip=64

#fdtdump ./dts/upstream/src/arm64/rockchip/rk3588-aigo-s60.dtb > rk3588-aigo-s60.dts
#fdtdump ./spl/dts/dt-spl.dtb > dt-spl.dts

#ls -alh   dts/upstream/src/arm64/rockchip/rk3588-aigo-s60.dts
#ls -alh   configs/aigo-s60-rk3588_defconfig
ls -alh   output/

echo "All done!"
