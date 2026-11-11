#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
out=${PHX_BUILD_DIR:-"$repo/.build/phx-r3588"}
firmware=${PHX_FIRMWARE_DIR:-"$repo/.build/rkbin"}
release=${PHX_OUTPUT_DIR:-"$repo/output/phx-r3588"}
mkdir -p "$out" "$firmware" "$release"
fetch() {
    local name=$1 hash=$2 revision=$3
    if ! printf '%s  %s\n' "$hash" "$firmware/$name" | sha256sum -c --status; then
        curl --fail --location --retry 3 "https://raw.githubusercontent.com/rockchip-linux/rkbin/$revision/bin/rk35/$name" -o "$firmware/$name.download"
        printf '%s  %s\n' "$hash" "$firmware/$name.download" | sha256sum -c -
        mv "$firmware/$name.download" "$firmware/$name"
    fi
}
fetch rk3588_bl31_v1.51.elf 2847c82a44aff28f1923eea31567c9cf01a7c4bcec4d3b9be1cbf6fcc965f84b 8126eaeac3110595cf21576e6028362ea09cc7c3
fetch rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin e109f3e283c86ad74b6574f5538b11750dea4cab7668175717aa2af7994c28ef f973f5335bcce3a0459c540e828874303505a5bf
export ARCH=arm CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
export BL31="$firmware/rk3588_bl31_v1.51.elf"
export ROCKCHIP_TPL="$firmware/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin"
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$repo" show -s --format=%ct HEAD)}
make -C "$repo" O="$out" phx-r3588_defconfig
make -C "$repo" O="$out" -j"${JOBS:-$(nproc)}"
# printinitialenv does not track all board-header dependencies.
rm -f "$out/tools/printinitialenv" "$out/u-boot-initial-env"
make -C "$repo" O="$out" u-boot-initial-env
for file in u-boot-rockchip.bin idbloader.img u-boot.itb u-boot.bin; do
    install -m 644 "$out/$file" "$release/$file"
done
install -m 644 "$out/u-boot-initial-env" "$release/initial-env.txt"
install -m 644 "$out/dts/dt.dtb" "$release/rk3588-phx-r3588-uboot.dtb"
mkenvimage -r -s 0x20000 -o "$release/default-env.bin" "$release/initial-env.txt"
(cd "$release" && sha256sum *.bin *.img *.itb *.dtb initial-env.txt > SHA256SUMS)
printf 'Build output: %s\n' "$release"
