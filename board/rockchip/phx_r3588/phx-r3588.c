// SPDX-License-Identifier: GPL-2.0+
#include <adc.h>
#include <dm.h>
#include <env.h>
#include <linux/delay.h>
#include <power/regulator.h>

int rk_board_late_init(void)
{
    struct udevice *dev;
    const char *const controls[] = { "usb_hub_reset", "wifi_enable" };
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

    if (uclass_get_device_by_driver(UCLASS_ADC,
            DM_DRIVER_GET(rockchip_saradc), &dev))
        return false;
    for (i = 0; i < 5; i++) {
        if (adc_channel_single_shot(dev->name, 1, &value) || value > 128)
            return false;
        mdelay(20);
    }
    env_set("recovery_key", "1");
    printf("PHX-R3588: recovery key held\n");
    return false;
}
