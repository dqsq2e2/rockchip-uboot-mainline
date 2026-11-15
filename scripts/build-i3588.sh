#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE
repo=$(cd "$(dirname "$0")/.." && pwd)
out=${I3588_BUILD_DIR:-"$repo/.build/i3588"}
firmware=${I3588_FIRMWARE_DIR:-"$repo/.build/i3588-firmware"}
release=${I3588_OUTPUT_DIR:-"$repo/output/i3588"}
mkdir -p "$out" "$release"
export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
bash "$repo/scripts/prepare-i3588-firmware.sh" "$firmware"
export ARCH=arm BL31="$firmware/bl31.elf"
export ROCKCHIP_TPL="$firmware/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin"
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$repo" show -s --format=%ct HEAD)}
make -C "$repo" O="$out" 9tripod-I3588_defconfig
make -C "$repo" O="$out" -j"${JOBS:-$(nproc)}"
rm -f "$out/tools/printinitialenv" "$out/u-boot-initial-env"
make -C "$repo" O="$out" u-boot-initial-env
for file in u-boot-rockchip.bin idbloader.img u-boot.itb u-boot.bin; do
    install -m 644 "$out/$file" "$release/$file"
done
install -m 644 "$out/u-boot-initial-env" "$release/initial-env.txt"
install -m 644 "$out/dts/dt.dtb" "$release/rk3588-9tripod-I3588-uboot.dtb"
install -m 644 "$out/.config" "$release/build.config"
cp "$firmware/REVISIONS" "$firmware/firmware.sha256" "$release/"
mkenvimage -r -s 0x20000 -o "$release/default-env.bin" "$release/initial-env.txt"
(cd "$release" && sha256sum *.bin *.img *.itb *.dtb initial-env.txt build.config > SHA256SUMS)
printf 'Build output: %s\n' "$release"
