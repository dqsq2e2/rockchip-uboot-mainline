# 9Tripod I3588 主线 U-Boot

本分支为九鼎 I3588（RK3588）适配主线 U-Boot。板级配置为 `configs/9tripod-I3588_defconfig`。

在 Linux 安装 AArch64 交叉工具链和 U-Boot 构建依赖后运行 `bash scripts/build-i3588.sh`。脚本准备匹配的 DDR 初始化固件和 TF-A，生成 `output/i3588/` 下的 loader、环境和校验文件；可用 `I3588_BUILD_DIR`、`I3588_FIRMWARE_DIR`、`I3588_OUTPUT_DIR` 和 `JOBS` 设置路径及并行度。CI 构建配置见 `.github/workflows/`。

独立恢复系统与系统整盘 IMG 均包含此板的 U-Boot；[恢复系统分支](https://github.com/dqsq2e2/rockchip-ophub-linux-6.18.y/tree/9tripod-i3588-recovery) 介绍恢复和分区映射。SW1 VOL+/RECOVERY 的条件分流需实际按键验证；SW7 BOOT 为硬件强制 Maskrom。eMMC 启动已实测，NVMe、SATA、USB 和 TF 启动尚未使用外部介质实测。串口 1500000 baud。

通用上游说明保留在 [README](README)。
