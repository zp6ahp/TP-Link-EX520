#!/bin/bash
# Сборка initramfs-образа OpenWrt для TP-Link EX520 в Linux-контейнере (Colima).
set -euo pipefail

SRC="/Users/evgeniy/Documents/Dev/EX520"
OWRT="$SRC/openwrt-src"
OUT="$SRC/build/out"
VOL="owrt-ex520"
IMAGE="ex520-builder:24.04"
JOBS="${JOBS:-8}"

mkdir -p "$OUT"
chmod 777 "$OUT"
docker volume create "$VOL" >/dev/null

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> Собираю образ сборщика"
  docker build -t "$IMAGE" "$SRC/build"
fi

echo "==> Готовлю дерево OpenWrt в томе $VOL (клон хранится в томе и переиспользуется)"
COMMIT="$(git -C "$OWRT" rev-parse HEAD)"
echo "    коммит: $COMMIT"
docker run --rm -v "$VOL:/home/build" -e COMMIT="$COMMIT" "$IMAGE" bash -c '
  set -e
  cd /home/build
  if [ ! -d openwrt/.git ]; then
    echo "    клонирую исходники (один раз, ~5-10 мин)"
    rm -rf openwrt
    git clone --filter=blob:none --no-checkout \
      https://github.com/openwrt/openwrt.git openwrt
  fi
  cd openwrt
  git checkout -f "$COMMIT"
'

echo "==> Накладываю правки EX520"
docker run --rm -v "$VOL:/home/build" -v "$OWRT:/src:ro" "$IMAGE" bash -c '
  set -e
  cd /home/build/openwrt
  cp /src/target/linux/mediatek/dts/mt7981b-tplink-ex520.dts \
     target/linux/mediatek/dts/
  cp /src/target/linux/mediatek/image/filogic.mk \
     target/linux/mediatek/image/filogic.mk
  cp /src/target/linux/mediatek/filogic/base-files/etc/board.d/01_leds \
     target/linux/mediatek/filogic/base-files/etc/board.d/01_leds
  cp /src/target/linux/mediatek/filogic/base-files/etc/board.d/02_network \
     target/linux/mediatek/filogic/base-files/etc/board.d/02_network
  cp /src/target/linux/mediatek/filogic/base-files/etc/hotplug.d/ieee80211/11_fix_wifi_mac \
     target/linux/mediatek/filogic/base-files/etc/hotplug.d/ieee80211/11_fix_wifi_mac
  cp /src/target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh \
     target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh
  rm -rf package/firmware/mt7981-eeprom-default
  cp -R /src/package/firmware/mt7981-eeprom-default package/firmware/
'

echo "==> Проверяю feeds LuCI/packages"
docker run --rm -v "$VOL:/home/build" "$IMAGE" bash -c '
  set -e
  cd /home/build/openwrt
  if [ ! -d feeds/luci ] || [ -z "$(ls -A package/feeds/luci 2>/dev/null)" ]; then
    ./scripts/feeds update luci
    ./scripts/feeds install -a -p luci
  fi
  if [ ! -d package/feeds/packages/cgi-io ]; then
    ./scripts/feeds update packages
    ./scripts/feeds install cgi-io luasrcdiet
  fi
'

echo "==> Конфигурация"
docker run --rm -v "$VOL:/home/build" "$IMAGE" bash -c '
  set -e
  cd /home/build/openwrt
  cat > .config <<EOF
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_tplink_ex520-v1=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_DEBUG_INFO=n
CONFIG_CCACHE=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-proto-relay=y
CONFIG_PACKAGE_relayd=y
EOF
  make defconfig
  echo "--- проверка устройства ---"
  grep -E "tplink_ex520|INITRAMFS" .config || true
'

echo "==> Сборка (make -j$JOBS), это займёт 30-60 минут"
docker run --rm -v "$VOL:/home/build" -e JOBS="$JOBS" "$IMAGE" bash -c '
  set -e -o pipefail
  cd /home/build/openwrt
  make -j"$JOBS" 2>&1 | tee /home/build/build.log | tail -n 60
'

echo "==> Копирую образы"
docker run --rm -u 0 -v "$VOL:/home/build" -v "$OUT:/out" "$IMAGE" bash -c '
  set -e
  find /home/build/openwrt/bin/targets -type f \( -name "*.bin" -o -name "*.itb" -o -name "*.tar" \) -print0 |
    xargs -0 -r cp -v -t /out/
'

echo "==> Собираю sysupgrade tar с metadata"
bash "$SRC/build/make-sysupgrade-tar.sh"

echo "==> Готово: $OUT"
ls -lh "$OUT"
