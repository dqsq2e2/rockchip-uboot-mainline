// SPDX-License-Identifier: GPL-2.0+
#include <adc.h>
#include <command.h>
#include <dm.h>
#include <dm/device-internal.h>
#include <dm/uclass.h>
#include <dm/uclass-internal.h>
#include <env.h>
#include <i2c.h>
#include <time.h>
#include <linux/delay.h>
#include <linux/usb/gadget.h>

#define DOWNLOAD_ADC_MIN 341 /* 150 mV, 12-bit ADC at 1.8 V */
#define DOWNLOAD_ADC_MAX 569 /* 250 mV */
#define DOWNLOAD_SAMPLES 5
#define OTG_HOST_WAIT_MS 2500
#define NCA9555_ADDR 0x20
#define NCA9555_OUTPUT0 0x02
#define NCA9555_CONFIG0 0x06
#define USB_POWER_MASK (BIT(0) | BIT(1) | BIT(7))

static int aiot3588a2_update_power(struct udevice *bus, u8 reg, bool high)
{
    u8 data[] = { reg, 0 };
    struct i2c_msg msgs[] = {
        { .addr = NCA9555_ADDR, .len = 1, .buf = data },
        { .addr = NCA9555_ADDR, .flags = I2C_M_RD, .len = 1, .buf = data + 1 },
    };
    int ret;

    ret = i2c_get_ops(bus)->xfer(bus, msgs, ARRAY_SIZE(msgs));
    if (ret)
        return ret;
    if (high)
        data[1] |= USB_POWER_MASK;
    else
        data[1] &= ~USB_POWER_MASK;
    msgs[0].len = sizeof(data);
    return i2c_get_ops(bus)->xfer(bus, msgs, 1);
}

int rockchip_early_misc_init_r(void)
{
    struct udevice *bus;
    int i, ret;

    ret = uclass_get_device_by_ofnode(UCLASS_I2C, ofnode_path("/i2c@fec80000"), &bus);
    if (!ret) {
        /* Set output latches first and leave the other expander lines intact. */
        for (i = 0; i < 10; i++) {
            ret = aiot3588a2_update_power(bus, NCA9555_OUTPUT0, true);
            if (!ret)
                ret = aiot3588a2_update_power(bus, NCA9555_CONFIG0, false);
            if (!ret)
                break;
            mdelay(20);
        }
        if (!ret)
            mdelay(100);
    }
    if (ret)
        printf("AIOT-3588A V2.0: USB host power setup failed (%d)\n", ret);
    return 0;
}

static struct usb_gadget *probe_gadget;
static bool probe_setup_seen;

static int aiot3588a2_probe_bind(struct usb_gadget *gadget)
{
    probe_gadget = gadget;
    return 0;
}

static void aiot3588a2_probe_unbind(struct usb_gadget *gadget)
{
    probe_gadget = NULL;
}

static int aiot3588a2_probe_setup(struct usb_gadget *gadget,
                           const struct usb_ctrlrequest *request)
{
    probe_setup_seen = true;
    return -EOPNOTSUPP;
}

static void aiot3588a2_probe_disconnect(struct usb_gadget *gadget)
{
}

static struct usb_gadget_driver aiot3588a2_probe_driver = {
    .function = "aiot3588a2-host-probe",
    .speed = USB_SPEED_HIGH,
    .bind = aiot3588a2_probe_bind,
    .unbind = aiot3588a2_probe_unbind,
    .setup = aiot3588a2_probe_setup,
    .disconnect = aiot3588a2_probe_disconnect,
};

/* OTG0 must observe a host handshake; VBUS alone is insufficient. */
static bool aiot3588a2_otg_host_connected(void)
{
    struct udevice *peripheral;
    ofnode node = ofnode_path("/usb@fc000000");
    bool connected = false;
    ulong start;
    int ret;

    ret = uclass_find_device_by_ofnode(UCLASS_USB_GADGET_GENERIC, node,
                                      &peripheral);
    if (ret) {
        printf("AIOT-3588A V2.0 OTG: download controller unavailable (%d)\n", ret);
        return false;
    }
    if (device_active(peripheral)) {
        printf("AIOT-3588A V2.0 OTG: download controller is already in use\n");
        return false;
    }
    ret = device_probe(peripheral);
    if (ret) {
        printf("AIOT-3588A V2.0 OTG: peripheral probe failed (%d)\n", ret);
        return false;
    }

    probe_setup_seen = false;
    ret = usb_gadget_register_driver(&aiot3588a2_probe_driver);
    if (ret) {
        printf("AIOT-3588A V2.0 OTG: gadget registration failed (%d)\n", ret);
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
    usb_gadget_unregister_driver(&aiot3588a2_probe_driver);
remove:
    ret = device_remove(peripheral, DM_REMOVE_NORMAL);
    if (ret) {
        printf("AIOT-3588A V2.0 OTG: peripheral cleanup failed (%d)\n", ret);
        return false;
    }
    printf("AIOT-3588A V2.0 OTG: USB host handshake %s\n",
           connected ? "detected" : "not detected");
    return connected;
}

static int do_aiot3588a2_otgprobe(struct cmd_tbl *cmdtp, int flag, int argc,
                          char *const argv[])
{
    return aiot3588a2_otg_host_connected() ? CMD_RET_SUCCESS : CMD_RET_FAILURE;
}

U_BOOT_CMD(aiot3588a2_otgprobe, 1, 0, do_aiot3588a2_otgprobe,
           "check download USB for a host without exposing storage", "");

/* The board's only button is the 200 mV download key on ADC1. */
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
            value < DOWNLOAD_ADC_MIN || value > DOWNLOAD_ADC_MAX)
            return false;
        mdelay(20);
    }
    if (aiot3588a2_otg_host_connected()) {
        printf("AIOT-3588A V2.0: download key held with USB host, returning to BootROM Maskrom\n");
        return true;
    }
    env_set("recovery_key", "1");
    printf("AIOT-3588A V2.0: download key held without USB host, booting recovery\n");
    return false;
}
