// SPDX-License-Identifier: GPL-2.0+
/*
 * Implements the 'rbrom' command to reboot into Rockchip Maskrom mode
 *
 * Copyright (C) 2024 Rockchip Electronics Co., Ltd.
 */

#include <command.h>
#include <asm/io.h>
#include <asm/arch-rockchip/boot_mode.h>
#include <linux/delay.h>

/* 
 * Ensure BOOT_BROM_DOWNLOAD is defined. 
 * Usually found in asm/arch-rockchip/boot_mode.h, 
 * but defined here as fallback for compatibility.
 */
#ifndef BOOT_BROM_DOWNLOAD
#define BOOT_BROM_DOWNLOAD	0x52424330  /* "RBC0" */
#endif

static int do_reboot_brom(struct cmd_tbl *cmdtp, int flag, int argc,
			  char *const argv[])
{
	u32 reg_val;

	/* 1. Read and print register value before write */
	reg_val = readl(CONFIG_ROCKCHIP_BOOT_MODE_REG);
	printf("Boot Mode Reg BEFORE write: 0x%08x to Reg 0x%08x\n",
	       reg_val, CONFIG_ROCKCHIP_BOOT_MODE_REG);

	/*
	 * These SOC_CON1 regs needs to be cleared before a reset or the
	 * BOOT_MODE_REG do not retain its value and it is not possible
	 * to reset to bootrom download mode once TF-A has been started.
	 *
	 * TF-A blobs for RK3568 already clear SOC_CON1 for PSCI reset.
	 * However, the TF-A blobs for RK3588 does not clear SOC_CON1.
	 */
	if (IS_ENABLED(CONFIG_ROCKCHIP_RK3568))
		writel(0x40000, 0xFDC20104);
	if (IS_ENABLED(CONFIG_ROCKCHIP_RK3588))
		writel(0xFFFF0000, 0xFD58A004);

	/* 2. Write the Maskrom download magic */
	writel(BOOT_BROM_DOWNLOAD, CONFIG_ROCKCHIP_BOOT_MODE_REG);

	/* 3. Small delay to ensure hardware latches the write */
	udelay(1000);

	/* 4. Read back and verify the written value */
	reg_val = readl(CONFIG_ROCKCHIP_BOOT_MODE_REG);
	printf("Boot Mode Reg AFTER write:  0x%08x\n", reg_val);
	printf("Expected value:             0x%08x\n", BOOT_BROM_DOWNLOAD);

	if (reg_val == BOOT_BROM_DOWNLOAD)
		printf("Write SUCCESS! Rebooting to Maskrom...\n");
	else
		printf("Write FAILED! Value mismatch.\n");

	/* 5. Trigger system reset */
	do_reset(NULL, 0, 0, NULL);

	/* Should never reach here */
	return CMD_RET_SUCCESS;
}


U_BOOT_CMD(rockusb, 4, 1, do_reboot_brom,
	   "use the rockusb protocol",
	   "<USB_controller> <devtype> <dev[:part]>  e.g. rockusb 0 mmc 0\n"
);
