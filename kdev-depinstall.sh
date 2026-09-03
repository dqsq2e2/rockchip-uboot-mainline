#!/usr/bin/bash

set -x

sudo apt-get update
sudo apt-get install -y \
    git make gcc-aarch64-linux-gnu \
    device-tree-compiler python3 python3-pip \
    bison flex libssl-dev libncurses-dev \
    swig python3-pyelftools uuid-dev libgnutls28-dev

