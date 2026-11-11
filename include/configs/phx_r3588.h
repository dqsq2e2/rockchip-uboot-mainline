/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __PHX_R3588_H
#define __PHX_R3588_H

#include <configs/rk3588_common.h>

/* Isolate this board from the other board recovery environments. */
#undef CFG_EXTRA_ENV_SETTINGS
#define CFG_EXTRA_ENV_SETTINGS \
	ENV_MEM_LAYOUT_SETTINGS \
	"fdtfile=" CONFIG_DEFAULT_FDT_FILE "\0" \
	"stdout=serial\0" \
	"stderr=serial\0" \
	"boot_targets=usb nvme mmc1 mmc0\0" \
	"recovery_key=0\0" \
	"boot_system=run boot_system_usb; run boot_system_nvme; run boot_system_sd; run boot_system_emmc; run recovery_boot\0" \
	"boot_system_usb=usb start; setenv devtype usb; for devnum in 0 1; do if usb dev ${devnum}; then run phx_scan; fi; done\0" \
	"boot_system_nvme=pci enum; nvme scan; setenv devtype nvme; for devnum in 0 1; do if nvme dev ${devnum}; then run phx_scan; fi; done\0" \
	"boot_system_sd=setenv devtype mmc; setenv devnum 1; mmc dev 1; if mmc rescan; then run phx_scan; fi\0" \
	"boot_system_emmc=setenv devtype mmc; setenv devnum 0; mmc dev 0; if mmc rescan; then run phx_scan; fi\0" \
	"phx_scan=" \
		"setenv phx_parts; if part list ${devtype} ${devnum} phx_parts; then " \
			"for distro_bootpart in ${phx_parts}; do " \
				"if part name ${devtype} ${devnum} 0x${distro_bootpart} phx_name; then " \
					"if test \"${phx_name}\" != PHX_RECOVERY; then run phx_boot_part; fi; " \
				"fi; " \
			"done; " \
		"fi\0" \
	"phx_boot_part=" \
		"for prefix in / /boot/; do " \
			"if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}extlinux/extlinux.conf; then " \
				"sysboot ${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} ${prefix}extlinux/extlinux.conf; " \
			"fi; " \
			"if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}boot.scr; then " \
				"if load ${devtype} ${devnum}:${distro_bootpart} ${scriptaddr} ${prefix}boot.scr; then source ${scriptaddr}; fi; " \
			"fi; " \
		"done\0" \
	"phx_recovery_part=if part name ${devtype} ${devnum} 1 phx_name; then if test \"${phx_name}\" = PHX_RECOVERY; then sysboot ${devtype} ${devnum}:1 any ${scriptaddr} /extlinux/extlinux.conf; fi; fi\0" \
	"recovery_boot=" \
		"echo PHX-R3588 Recovery; setenv devtype mmc; " \
		"for devnum in 0 1; do if mmc dev ${devnum} && mmc rescan; then run phx_recovery_part; fi; done; " \
		"usb start; setenv devtype usb; for devnum in 0 1; do if usb dev ${devnum}; then run phx_recovery_part; fi; done; " \
		"pci enum; nvme scan; setenv devtype nvme; for devnum in 0 1; do if nvme dev ${devnum}; then run phx_recovery_part; fi; done\0"

#endif
