// SPDX-License-Identifier: GPL-2.0+
#include <adc.h>
#include <command.h>
#include <dm.h>
#include <dm/device-internal.h>
#include <dm/uclass.h>
#include <dm/uclass-internal.h>
#include <env.h>
#include <time.h>
#include <linux/delay.h>
#include <linux/usb/gadget.h>
#include <power/regulator.h>

#define DOWNLOAD_ADC_MAX 128
#define DOWNLOAD_SAMPLES 5
#define OTG_HOST_WAIT_MS 2500

static struct usb_gadget *probe_gadget;
static bool probe_setup_seen;

static int i3588_probe_bind(struct usb_gadget *gadget)
{
    probe_gadget = gadget;
    return 0;
}

static void i3588_probe_unbind(struct usb_gadget *gadget)
{
    probe_gadget = NULL;
}

static int i3588_probe_setup(struct usb_gadget *gadget,
                           const struct usb_ctrlrequest *request)
{
    probe_setup_seen = true;
    return -EOPNOTSUPP;
}

static void i3588_probe_disconnect(struct usb_gadget *gadget)
{
}

static struct usb_gadget_driver i3588_probe_driver = {
    .function = "i3588-host-probe",
    .speed = USB_SPEED_HIGH,
    .bind = i3588_probe_bind,
    .unbind = i3588_probe_unbind,
    .setup = i3588_probe_setup,
    .disconnect = i3588_probe_disconnect,
};

/* OTG0 must observe a host handshake; VBUS alone is insufficient. */
static bool i3588_otg_host_connected(void)
{
    struct udevice *peripheral;
    ofnode node = ofnode_path("/usb@fc000000");
    bool connected = false;
    ulong start;
    int ret;

    ret = uclass_find_device_by_ofnode(UCLASS_USB_GADGET_GENERIC, node,
                                      &peripheral);
    if (ret) {
        printf("I3588 OTG: download controller unavailable (%d)\n", ret);
        return false;
    }
    if (device_active(peripheral)) {
        printf("I3588 OTG: download controller is already in use\n");
        return false;
    }
    ret = device_probe(peripheral);
    if (ret) {
        printf("I3588 OTG: peripheral probe failed (%d)\n", ret);
        return false;
    }

    probe_setup_seen = false;
    ret = usb_gadget_register_driver(&i3588_probe_driver);
    if (ret) {
        printf("I3588 OTG: gadget registration failed (%d)\n", ret);
        goto remove;
    }
    start = get_timer(0);
    while (get_timer(start) < OTG_HOST_WAIT_MS) {
        ret = dm_usb_gadget_handle_interrupts(peripheral);
        if (ret)
            break;
        if (probe_setup_seen ||
            (probe_gadget && probe_gadget->speed != USB_SPEED_UNKNOWN)) {
            connected = true;
            break;
        }
        udelay(1000);
    }
    usb_gadget_unregister_driver(&i3588_probe_driver);
remove:
    ret = device_remove(peripheral, DM_REMOVE_NORMAL);
    if (ret) {
        printf("I3588 OTG: peripheral cleanup failed (%d)\n", ret);
        return false;
    }
    printf("I3588 OTG: USB host handshake %s\n",
           connected ? "detected" : "not detected");
    return connected;
}

static int do_i3588_otgprobe(struct cmd_tbl *cmdtp, int flag, int argc,
                          char *const argv[])
{
    return i3588_otg_host_connected() ? CMD_RET_SUCCESS : CMD_RET_FAILURE;
}

U_BOOT_CMD(i3588_otgprobe, 1, 0, do_i3588_otgprobe,
           "check download USB for a host without exposing storage", "");

int rk_board_late_init(void)
{
    struct udevice *dev;
    const char *const controls[] = { "wifi_enable" };
    int i, ret;

    /* Reset peripheral state even when the previous OS left firmware active. */
    for (i = 0; i < ARRAY_SIZE(controls); i++) {
        ret = regulator_get_by_platname(controls[i], &dev);
        if (ret)
            return ret;
        ret = regulator_set_enable(dev, false);
        if (ret && ret != -EALREADY)
            return ret;
        mdelay(50);
        ret = regulator_set_enable(dev, true);
        if (ret)
            return ret;
    }
    return 0;
}

/* Factory ADC1 ladder: recovery/volume-up at 17 mV, idle at 1.8 V. */
int rockchip_dnl_key_pressed(void)
{
    struct udevice *dev;
    unsigned int value;
    int i;

    /* This key state is sampled per boot, even if an old env was saved. */
    env_set("recovery_key", "0");
    if (uclass_get_device_by_driver(UCLASS_ADC,
            DM_DRIVER_GET(rockchip_saradc), &dev))
        return false;
    for (i = 0; i < DOWNLOAD_SAMPLES; i++) {
        if (adc_channel_single_shot(dev->name, 1, &value) ||
            value > DOWNLOAD_ADC_MAX)
            return false;
        mdelay(20);
    }
    if (i3588_otg_host_connected()) {
        printf("9Tripod I3588: VOL+/RECOVERY held with USB host, returning to BootROM Maskrom\n");
        return true;
    }
    env_set("recovery_key", "1");
    printf("9Tripod I3588: VOL+/RECOVERY held without USB host, booting recovery\n");
    return false;
}
