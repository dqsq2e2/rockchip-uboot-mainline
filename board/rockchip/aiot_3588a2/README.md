# SMDT AIOT-3588A V2.0 U-Boot

Build `aiot-3588a2_defconfig` with an AArch64 toolchain, RK3588 DDR
firmware (`ROCKCHIP_TPL`) and TF-A (`BL31`):

```sh
BL31=/path/to/bl31.elf ROCKCHIP_TPL=/path/to/ddr.bin \
    bash scripts/build-aiot-3588a2.sh
```

TTL1 uses UART1 at 1500000 baud (8N1). The boot command looks for
extlinux or boot.scr on USB, NVMe, SATA, TF and eMMC. The bootloader
starts at LBA 64. Two environment copies are at 16 MiB and 16 MiB +
128 KiB on eMMC.

The download key is sampled on ADC channel 1. When held, a host
handshake on the download USB port requests BootROM Maskrom.
Otherwise U-Boot attempts to boot the GPT partition named
`AIOT_RECOVERY`.
