#!/bin/bash
# Build OpenWrt for TP-Link EX520 v1 from the released patch.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"              # release/src
OUT="${OUT:-$(cd "$SRC/.." && pwd)/bin}"             # release/bin
VOL="${VOL:-owrt-ex520-build}"
IMAGE="${IMAGE:-ex520-builder:24.04}"
JOBS="${JOBS:-8}"
COMMIT="${COMMIT:-bb8054e}"
PATCH="$SRC/patches/openwrt-ex520-v1.patch"
CONFIG="$SRC/config.seed"

[ -f "$PATCH" ] || { echo "missing $PATCH"; exit 1; }
[ -f "$CONFIG" ] || { echo "missing $CONFIG"; exit 1; }

mkdir -p "$OUT"
chmod 777 "$OUT"
docker volume create "$VOL" >/dev/null

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "==> building $IMAGE"
    docker build -t "$IMAGE" "$SRC/build"
fi

echo "==> preparing OpenWrt $COMMIT in volume $VOL"
docker run --rm -v "$VOL:/home/build" -e COMMIT="$COMMIT" "$IMAGE" bash -c '
  set -e
  cd /home/build
  if [ ! -d openwrt/.git ]; then
    git clone --filter=blob:none https://github.com/openwrt/openwrt.git openwrt
  fi
  cd openwrt
  git fetch --all --tags >/dev/null 2>&1 || true
  git checkout -f "$COMMIT"
  git reset --hard "$COMMIT"
'

echo "==> applying EX520 patch"
docker run --rm -v "$VOL:/home/build" -v "$SRC:/src:ro" "$IMAGE" bash -c '
  set -e
  cd /home/build/openwrt
  rm -rf package/firmware/mt7981-eeprom-default
  rm -f target/linux/mediatek/dts/mt7981b-tplink-ex520.dts
  git apply --whitespace=nowarn --binary /src/patches/openwrt-ex520-v1.patch
'

echo "==> feeds"
docker run --rm -v "$VOL:/home/build" "$IMAGE" bash -c '
  set -e
  cd /home/build/openwrt
  ./scripts/feeds update luci packages
  ./scripts/feeds install -a -p luci
  ./scripts/feeds install cgi-io luasrcdiet
'

echo "==> config"
docker run --rm -v "$VOL:/home/build" -v "$SRC:/src:ro" "$IMAGE" bash -c '
  set -e
  cd /home/build/openwrt
  cp /src/config.seed .config
  make defconfig
  grep -E "tplink_ex520|INITRAMFS" .config || true
'

echo "==> build"
docker run --rm -v "$VOL:/home/build" -e JOBS="$JOBS" "$IMAGE" bash -c '
  set -e -o pipefail
  cd /home/build/openwrt
  make -j"$JOBS" 2>&1 | tee /home/build/build.log | tail -n 60
'

echo "==> copy images"
docker run --rm -u 0 -v "$VOL:/home/build" -v "$OUT:/out" "$IMAGE" bash -c '
  set -e
  find /home/build/openwrt/bin/targets -type f \( -name "*.bin" -o -name "*.itb" \) -print0 |
    xargs -0 -r cp -v -t /out/
'

echo "==> sysupgrade tar + metadata"
VOL="$VOL" IMAGE="$IMAGE" OUT_DIR="$OUT" "$SRC/build/make-sysupgrade-tar.sh"

echo "==> done: $OUT"
ls -lh "$OUT"
