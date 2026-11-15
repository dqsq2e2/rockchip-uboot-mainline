# PHX-R3588 主线 U-Boot

本分支适配 PHX-R3588 V02（RK3588）底板，配置为 `configs/phx-r3588_defconfig`。

在 Linux 安装 AArch64 交叉工具链和 U-Boot 构建依赖后运行 `bash scripts/build-phx-r3588.sh`。脚本校验并准备 DDR 和 BL31 固件，输出 loader、默认环境与校验文件到 `output/phx-r3588/`；可通过 `PHX_BUILD_DIR`、`PHX_FIRMWARE_DIR`、`PHX_OUTPUT_DIR` 和 `JOBS` 调整。CI 配置见 `.github/workflows/`。

[恢复系统分支](https://github.com/dqsq2e2/rockchip-ophub-linux-6.18.y/tree/phx-r3588-recovery) 提供包含 U-Boot 的独立恢复镜像和系统分区映射方案。系统整盘镜像也包含 U-Boot，可独立刷写。下载键连接电脑时进入 Maskrom，未连接时进入已安装恢复系统；该行为已实测。eMMC 启动已验证，NVMe、USB、TF 外部介质启动未实测。串口 115200 baud。

通用上游说明保留在 [README](README)。
