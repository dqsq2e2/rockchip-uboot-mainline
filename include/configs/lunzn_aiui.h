/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __LUNZN_AIUI_H
#define __LUNZN_AIUI_H

#include <configs/rk3588_common.h>

/* Isolate this board from the G98-specific SPI recovery environment. */
#undef CFG_EXTRA_ENV_SETTINGS
#define CFG_EXTRA_ENV_SETTINGS \
	ENV_MEM_LAYOUT_SETTINGS \
	"fdtfile=" CONFIG_DEFAULT_FDT_FILE "\0" \
	"stdout=serial\0" \
	"stderr=serial\0" \
	"boot_targets=usb nvme mmc1 mmc0\0" \
	"recovery_key=0\0" \
	"boot_system=run boot_system_usb; run boot_system_nvme; run boot_system_sd; run boot_system_emmc; run recovery_boot\0" \
	"boot_system_usb=usb start; setenv devtype usb; for devnum in 0 1; do if usb dev ${devnum}; then run lunzn_scan; fi; done\0" \
	"boot_system_nvme=pci enum; nvme scan; setenv devtype nvme; for devnum in 0 1; do if nvme dev ${devnum}; then run lunzn_scan; fi; done\0" \
	"boot_system_sd=setenv devtype mmc; setenv devnum 1; mmc dev 1; if mmc rescan; then run lunzn_scan; fi\0" \
	"boot_system_emmc=setenv devtype mmc; setenv devnum 0; mmc dev 0; if mmc rescan; then run lunzn_scan; fi\0" \
	"lunzn_scan=" \
		"setenv lunzn_parts; if part list ${devtype} ${devnum} lunzn_parts; then " \
			"for distro_bootpart in ${lunzn_parts}; do " \
				"if test ${devtype} = mmc && test ${devnum} = 0; then " \
					"if part start mmc 0 0x${distro_bootpart} lunzn_start; then " \
						"if itest.l ${lunzn_start} -ge 0x80000; then run lunzn_boot_part; fi; " \
					"fi; " \
				"else run lunzn_boot_part; fi; " \
			"done; " \
		"fi\0" \
	"lunzn_boot_part=" \
		"for prefix in / /boot/; do " \
			"if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}extlinux/extlinux.conf; then " \
				"sysboot ${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} ${prefix}extlinux/extlinux.conf; " \
			"fi; " \
			"if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}boot.scr; then " \
				"if load ${devtype} ${devnum}:${distro_bootpart} ${scriptaddr} ${prefix}boot.scr; then source ${scriptaddr}; fi; " \
			"fi; " \
		"done\0" \
	"recovery_boot=echo rk3588 AIUI Recovery; mmc dev 0; if mmc rescan; then sysboot mmc 0:1 any ${scriptaddr} /extlinux/extlinux.conf; fi\0"

#endif
