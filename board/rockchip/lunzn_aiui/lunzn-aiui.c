// SPDX-License-Identifier: GPL-2.0+
#include <adc.h>
#include <command.h>
#include <dm.h>
#include <dm/device-internal.h>
#include <dm/lists.h>
#include <dm/uclass.h>
#include <dm/uclass-internal.h>
#include <env.h>
#include <time.h>
#include <linux/delay.h>
#include <linux/errno.h>
#include <linux/printk.h>
#include <linux/usb/gadget.h>

/* Measured on this board: held 41-43, released 4088 (12-bit ADC). */
#define DOWNLOAD_ADC_MAX	128
#define DOWNLOAD_SAMPLES	5
#define OTG_HOST_WAIT_MS		2500

static struct usb_gadget *probe_gadget;
static bool probe_setup_seen;

static int lunzn_probe_bind(struct usb_gadget *gadget)
{
	probe_gadget = gadget;
	return 0;
}

static void lunzn_probe_unbind(struct usb_gadget *gadget)
{
	probe_gadget = NULL;
}

static int lunzn_probe_setup(struct usb_gadget *gadget,
			    const struct usb_ctrlrequest *request)
{
	probe_setup_seen = true;
	return -EOPNOTSUPP;
}

static void lunzn_probe_disconnect(struct usb_gadget *gadget)
{
}

static struct usb_gadget_driver lunzn_probe_driver = {
	.function = "lunzn-host-probe",
	.speed = USB_SPEED_HIGH,
	.bind = lunzn_probe_bind,
	.unbind = lunzn_probe_unbind,
	.setup = lunzn_probe_setup,
	.disconnect = lunzn_probe_disconnect,
};

/*
 * VBUS can remain valid with no PC attached. Temporarily probe OTG0 as a
 * USB2 device and require a host reset/speed negotiation or control request.
 * No storage function is registered, so this cannot accept flash commands.
 * Leave the unprobed host device bound for normal USB disk boot afterwards.
 */
static bool lunzn_otg_host_connected(void)
{
	struct udevice *host, *peripheral;
	ofnode node = ofnode_path("/usb@fc000000");
	bool connected = false;
	ulong start;
	int ret, cleanup;

	ret = uclass_find_device_by_ofnode(UCLASS_USB, node, &host);
	if (ret || device_active(host)) {
		printf("LUNZN OTG: host controller unavailable (%d)\n", ret);
		return false;
	}

	ret = device_bind_driver_to_node(host->parent,
					"dwc3-generic-peripheral",
					"lunzn-otg-probe", node, &peripheral);
	if (ret)
		return false;
	ret = device_probe(peripheral);
	if (ret) {
		printf("LUNZN OTG: peripheral probe failed (%d)\n", ret);
		goto unbind;
	}
	probe_setup_seen = false;
	ret = usb_gadget_register_driver(&lunzn_probe_driver);
	if (ret) {
		printf("LUNZN OTG: gadget registration failed (%d)\n", ret);
		goto remove;
	}
	start = get_timer(0);
	while (get_timer(start) < OTG_HOST_WAIT_MS) {
		dm_usb_gadget_handle_interrupts(peripheral);
		if (probe_setup_seen ||
		    (probe_gadget &&
		     probe_gadget->speed != USB_SPEED_UNKNOWN)) {
			connected = true;
			break;
		}
		udelay(1000);
	}
	usb_gadget_unregister_driver(&lunzn_probe_driver);
remove:
	cleanup = device_remove(peripheral, DM_REMOVE_NORMAL);
	if (cleanup) {
		printf("LUNZN OTG: peripheral cleanup failed (%d)\n", cleanup);
		return false;
	}
unbind:
	device_unbind(peripheral);
	printf("LUNZN OTG: USB host handshake %s\n",
	       connected ? "detected" : "not detected");
	return connected;
}

static int do_lunzn_otgprobe(struct cmd_tbl *cmdtp, int flag, int argc,
			     char *const argv[])
{
	lunzn_otg_host_connected();
	return CMD_RET_SUCCESS;
}

U_BOOT_CMD(lunzn_otgprobe, 1, 0, do_lunzn_otgprobe,
	   "check OTG0 for a real USB host without exposing storage", "");

int rockchip_dnl_key_pressed(void)
{
	struct udevice *dev;
	unsigned int value;
	int ret, i;

	ret = uclass_get_device_by_driver(UCLASS_ADC,
					 DM_DRIVER_GET(rockchip_saradc), &dev);
	if (ret) {
		pr_warn("Download key: SARADC unavailable (%d)\n", ret);
		return false;
	}

	for (i = 0; i < DOWNLOAD_SAMPLES; i++) {
		ret = adc_channel_single_shot(dev->name, 1, &value);
		if (ret) {
			pr_warn("Download key: SARADC1 read failed (%d)\n", ret);
			return false;
		}
		if (!i)
			printf("LUNZN download key: adc1=%u\n", value);
		if (value > DOWNLOAD_ADC_MAX)
			return false;
		mdelay(20);
	}

	if (lunzn_otg_host_connected()) {
		printf("LUNZN AIUI: reset held with OTG host, returning to BootROM Maskrom\n");
		return true;
	}

	env_set("recovery_key", "1");
	printf("LUNZN AIUI: reset held without OTG host, booting recovery\n");
	return false;
}
