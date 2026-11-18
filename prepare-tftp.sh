#!/bin/bash
set -e

SRC="/Users/evgeniy/Documents/Dev/EX520/build/out/openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin"
DST="/private/tftpboot/ex520.itb"

sudo cp "$SRC" "$DST"
sudo chmod 644 "$DST"

echo
echo "--- sha256 ---"
shasum -a 256 "$DST"
echo
echo "Ожидается: 4a3ac2c99aea27de4b88d9f8b4cda4887f2ab7c90ee78adde52d78bb5368a3de"
