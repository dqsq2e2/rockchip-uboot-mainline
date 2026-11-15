# 9Tripod I3588

Build with `bash scripts/build-i3588.sh`. This downloads the hash-checked
Rockchip DDR v1.08 binary and builds TF-A at the revision recorded in
`scripts/prepare-i3588-firmware.sh`. The output includes the combined loader,
individual components, redundant default environment and checksums.

The tested board has 4 GB LPDDR4X and CV1 CPU regulator wiring. Its factory
DDR v1.08 exposes the native low-memory bank. Later DDR binaries reclaim a
256 MiB bank above 4 GB, but the tested board shows repeatable read/write errors
near the end of that bank. Do not substitute a newer DDR binary without
validating its complete memory map. No Linux `mem=` override is required with
the selected factory map. Upstream TF-A also enables the HDMI receiver
interrupt routing needed by the mainline kernel.

The board uses UART2 at 1500000 baud. The raw combined loader starts at byte
32768. Redundant 128 KiB environments start at 16 MiB and 16 MiB + 128 KiB.
The loader must finish before the first environment. Build a partitioned disk
image before whole-disk installation; `u-boot-rockchip.bin` alone has no GPT.

Boot order is USB, NVMe, SATA, TF, eMMC, then recovery. Recovery is discovered
by the GPT name `I3588_RECOVERY`. Other partitions are scanned for extlinux
and boot scripts, including projected partitions behind the recovery area.
The SATA controller clocks and PHY must be enabled before AHCI probing.

SW1 (VOL+/RECOVERY, ADC1) samples the key and checks for a USB host handshake:
with a host it requests BootROM Maskrom; otherwise it selects recovery.
SW7 (BOOT, ADC0) directly forces BootROM Maskrom in hardware and cannot be
changed by U-Boot. SW6 is hardware RESET, SW5 is PMIC POWER and SW2 is VOL−.
