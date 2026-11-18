#!/bin/bash
set -e

SRC="/Users/evgeniy/Documents/Dev/EX520/build/out/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin"

echo "Ждём подключение роутера на порт 9995..."
echo "Не закрывайте это окно. В UART выполните: nc 192.168.1.2 9995 > /tmp/install.bin"
echo

exec /usr/bin/nc -l 9995 < "$SRC"
