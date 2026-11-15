# LUNZN RK3588 AIUI 主线 U-Boot

本分支为 LUNZN AIUI（RK3588）板适配主线 U-Boot。

板级配置为 `configs/lunzn-aiui-rk3588_defconfig`，设备树为 `dts/upstream/src/arm64/rockchip/rk3588-lunzn-AIUI.dts`，板级代码在 `board/rockchip/lunzn_aiui/`。构建需 AArch64 交叉工具链及与板子匹配的 Rockchip DDR 初始化固件和 BL31；设备专用引导镜像需依照实际构建流程组装并验证。

配套 [AIUI 恢复系统分支](https://github.com/dqsq2e2/rockchip-ophub-linux-6.18.y/tree/rk3588-aiui-recovery)。通用上游说明保留在 [README](README)。
