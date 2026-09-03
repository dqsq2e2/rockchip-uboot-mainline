#!/bin/bash

set -ex

make CROSS_COMPILE=aarch64-linux-gnu- \
	menuconfig

make CROSS_COMPILE=aarch64-linux-gnu- \
	savedefconfig

