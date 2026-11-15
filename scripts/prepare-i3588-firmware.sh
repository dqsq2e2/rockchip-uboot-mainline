#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE
cache=${1:?Usage: prepare-i3588-firmware.sh CACHE}
cache=$(realpath -m "$cache")
mkdir -p "$cache"
ddr=rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin
ddr_hash=138a2502bcea0cebe581833790060b21d39a67b603d8e7633d8505bd39adea7b
rkbin_revision=35c3e2e438d2a6983a958fd2d3a66076112bea23
tfa_revision=a881364e03b0c5b3a8c00f20ad6fbdda53a57031
if ! printf '%s  %s\n' "$ddr_hash" "$cache/$ddr" | sha256sum -c --status; then
    curl --fail --location --retry 3 \
        "https://raw.githubusercontent.com/rockchip-linux/rkbin/$rkbin_revision/bin/rk35/$ddr" \
        -o "$cache/$ddr.download"
    printf '%s  %s\n' "$ddr_hash" "$cache/$ddr.download" | sha256sum -c -
    mv "$cache/$ddr.download" "$cache/$ddr"
fi
tfa=${I3588_TFA_SOURCE:-"$cache/trusted-firmware-a"}
if [ ! -d "$tfa/.git" ]; then
    test ! -e "$tfa" || { echo "TF-A source path already exists: $tfa" >&2; exit 1; }
    git init "$tfa"
    git -C "$tfa" fetch --depth=1 https://github.com/ARM-software/arm-trusted-firmware.git "$tfa_revision"
    git -C "$tfa" checkout --detach FETCH_HEAD
fi
test "$(git -C "$tfa" rev-parse HEAD)" = "$tfa_revision"
git -C "$tfa" diff --quiet HEAD --
git -C "$tfa" submodule update --init --depth=1
make -C "$tfa" PLAT=rk3588 CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}" \
    -j"${JOBS:-$(nproc)}" bl31
install -m 644 "$tfa/build/rk3588/release/bl31/bl31.elf" "$cache/bl31.elf"
printf 'rkbin %s\nTF-A %s\n' "$rkbin_revision" "$tfa_revision" > "$cache/REVISIONS"
(cd "$cache" && sha256sum "$ddr" bl31.elf > firmware.sha256)
