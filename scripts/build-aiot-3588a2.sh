#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=${AIOT3588A2_BUILD_DIR:-"$HOME/.cache/aiot-3588a2-uboot"}
source_dir="$work/source"
output_dir="$work/build"
if [[ ${1:-} == --ramtest ]]; then
    output_dir="$work/build-ramtest"
elif [[ $# != 0 ]]; then
    echo "Usage: $0 [--ramtest]" >&2
    exit 2
fi
if gitdir=$(sed -n 's/^gitdir: //p' "$repo/.git" 2>/dev/null); then
    if [[ $gitdir == [A-Za-z]:* ]]; then
        gitdir=$(wslpath -u "$gitdir")
    fi
    export GIT_DIR="$gitdir" GIT_WORK_TREE="$repo"
fi
mkdir -p "$source_dir" "$output_dir"
git -C "$repo" archive HEAD | tar -xf - -C "$source_dir"
if [[ -n ${AIOT3588A2_PATCH:-} ]]; then
    git -C "$source_dir" apply "$AIOT3588A2_PATCH"
fi
unset GIT_DIR GIT_WORK_TREE
export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
export BL31=${BL31:?Set BL31 to the RK3588 TF-A ELF}
export ROCKCHIP_TPL=${ROCKCHIP_TPL:?Set ROCKCHIP_TPL to the RK3588 DDR binary}
test -s "$BL31"
test -s "$ROCKCHIP_TPL"
make -C "$source_dir" O="$output_dir" aiot-3588a2_defconfig
if [[ ${1:-} == --ramtest ]]; then
    "$source_dir/scripts/config" --file "$output_dir/.config" \
        --disable ENV_IS_IN_MMC --enable ENV_IS_NOWHERE --disable CMD_SAVEENV
    make -C "$source_dir" O="$output_dir" olddefconfig
fi
make -C "$source_dir" O="$output_dir" -j"${JOBS:-8}"
make -C "$source_dir" O="$output_dir" u-boot-initial-env
