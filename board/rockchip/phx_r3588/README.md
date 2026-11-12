# PHX-R3588

Board support for the PHX-R3588 V02 carrier and RK3588 core module.
UART2 debug console uses 115200 baud. The standard PCIe slot uses all four
PCIe 3.0 lanes; lane bifurcation is not enabled by this configuration.

## Build

On Linux with an AArch64 GNU cross compiler, U-Boot host tools and the usual
U-Boot build dependencies, run `bash scripts/build-phx-r3588.sh`.
The script verifies pinned Rockchip DDR/BL31 binaries and writes artifacts
under `output/phx-r3588/`. The build does not depend on another board tree.

## Disk layouts

The same loader supports two independent raw disk images. A recovery image
contains the loader, recovery filesystem and empty system area. A standalone
system image contains the loader and its own boot/root partitions; it does
not need a recovery partition. Both images can be written from LBA 0.

The common loader and environment locations are:

| Region | Byte offset | Length |
| --- | ---: | ---: |
| Rockchip loader | 32768 | see u-boot-rockchip.bin |
| Redundant environment A | 16777216 | 131072 |
| Redundant environment B | 16908288 | 131072 |

For the recovery image, `PHX_RECOVERY` occupies 33554432..268418047.
The recovery application can write a complete standalone system image at
byte 268435456 and map its partitions into the outer GPT, keeping their
PARTUUIDs. That operation retains the recovery image's outer loader and
environment. A direct whole-disk system flash instead uses the system
image's loader and native partition positions.

USB, NVMe, TF and eMMC are scanned in that order. A partition named
`PHX_RECOVERY` is skipped during normal scanning on every medium. Recovery
searches partition 1 on the supported media.

## Download button

Hold the download button before power-on or reset. SARADC channel 1 must
remain at or below 128 for five samples, 20 ms apart. With a USB data
connection to a PC on the Type-C download port, a real USB host handshake
on OTG0 requests BootROM Maskrom via the common Rockchip boot-mode reset.
It does not start a U-Boot RockUSB storage session. VBUS alone is not used
as the connection test.

Without a host handshake within 2.5 seconds, the held key selects recovery.
This requires an installed or externally attached `PHX_RECOVERY` partition;
a standalone system-only disk does not contain a recovery filesystem.
The connection probe is skipped when the key is released. The command
`phx_otgprobe` checks the download USB handshake without exposing storage
or resetting the board, and returns success only when a host is detected.

This environment layout is incompatible with the factory GPT. Do not run
`saveenv` against a factory disk. RAM testing must use ENV_IS_NOWHERE with
CMD_SAVEENV disabled and load U-Boot at its link address, 0x00800000.

## Validation boundaries

Full loader cold boots have verified eMMC reads, board regulators,
peripheral reset, operating-system boot and EHCI/XHCI scanning. OHCI is
disabled because the first host controller register access stalls on this
board. The on-board USB hub enumerates in the full U-Boot boot chain.
External USB, NVMe and
TF boot require a connected medium and must be tested separately.
