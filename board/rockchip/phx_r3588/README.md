# PHX-R3588

Board support for the PHX-R3588 V02 carrier and RK3588 core module.
UART2 debug console uses 115200 baud. The standard PCIe slot uses all four
PCIe 3.0 lanes; lane bifurcation is not enabled by this configuration.

## Build

On Linux with an AArch64 GNU cross compiler, U-Boot host tools and the usual
U-Boot build dependencies, run `bash scripts/build-phx-r3588.sh`.
The script verifies pinned Rockchip DDR/BL31 binaries and writes artifacts
under `output/phx-r3588/`. The build does not depend on another board tree.

## Disk layout

| Region | Byte offset | Length |
| --- | ---: | ---: |
| Rockchip loader | 32768 | see u-boot-rockchip.bin |
| Redundant environment A | 16777216 | 131072 |
| Redundant environment B | 16908288 | 131072 |
| PHX_RECOVERY | 33554432 | 234863616 |
| Embedded system disk | 268435456 | image dependent |

System partitions are mapped into the outer GPT and keep their PARTUUIDs.
USB, NVMe, TF and eMMC are scanned in that order. A partition named
`PHX_RECOVERY` is skipped during normal scanning on every medium. Recovery
searches partition 1 on the supported media. Holding the ADC1 recovery key
during boot selects recovery.

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
