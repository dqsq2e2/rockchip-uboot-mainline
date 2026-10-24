#!/usr/bin/bash

set -xe

md5sum u-boot-rockchip.bin
sshpass -p admin scp u-boot-rockchip.bin 192.168.33.39:/hack
sshpass -p admin ssh 192.168.33.39 md5sum /hack/u-boot-rockchip.bin
sshpass -p admin ssh 192.168.33.39 "cd /hack; ./hack.sh "

