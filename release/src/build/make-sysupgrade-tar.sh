#!/bin/bash
# Build a standard OpenWrt sysupgrade tar (kernel + root + CONTROL + metadata)
# from the FIT sysupgrade image produced by the filogic build.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"              # release/src/build
OUT_DIR="${OUT_DIR:-$(cd "$SRC_DIR/../.." && pwd)/bin}"
VOL="${VOL:-owrt-ex520-build}"
IMAGE="${IMAGE:-ex520-builder:24.04}"

FIT="$OUT_DIR/openwrt-mediatek-filogic-tplink_ex520-v1-squashfs-sysupgrade.bin"
WORK="$OUT_DIR/sysupgrade-work"
TAR="$OUT_DIR/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade.tar"
FINAL="$OUT_DIR/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin"
META="$OUT_DIR/metadata-ex520.json"

[ -f "$FIT" ] || { echo "missing $FIT"; exit 1; }

rm -rf "$WORK"
mkdir -p "$WORK/sysupgrade-tplink_ex520-v1"

python3 - "$FIT" "$WORK/sysupgrade-tplink_ex520-v1" <<'PY'
import struct, sys
src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
fit_size = struct.unpack('>I', d[4:8])[0]
root_off = d.find(b'hsqs')
if root_off < 0:
    raise SystemExit('squashfs magic not found')
root_size = struct.unpack('<Q', d[root_off+40:root_off+48])[0]
if fit_size <= 0 or root_size <= 0:
    raise SystemExit('bad sizes')
open(dst + '/kernel', 'wb').write(d[:fit_size])
open(dst + '/root', 'wb').write(d[root_off:root_off+root_size])
print(f'kernel: {fit_size} bytes (0x{fit_size:x})')
print(f'root:   {root_size} bytes (0x{root_size:x}) at 0x{root_off:x}')
PY

cat > "$WORK/sysupgrade-tplink_ex520-v1/CONTROL" <<EOF
BOARD=tplink,ex520-v1
SUPPORTED_DEVICES=tplink,ex520-v1
EOF

tar -C "$WORK" -cf "$TAR" sysupgrade-tplink_ex520-v1

cat > "$META" <<'EOF'
{
  "metadata_version": 1,
  "compat_version": "1.0",
  "supported_devices": ["tplink,ex520-v1"],
  "version": {
    "dist": "OpenWrt",
    "version": "SNAPSHOT",
    "revision": "unknown",
    "target": "mediatek/filogic",
    "board": "tplink_ex520-v1"
  }
}
EOF

cp "$TAR" "$FINAL"

docker run --rm -v "$VOL:/w" -v "$OUT_DIR:/out" "$IMAGE" bash -c '
  set -e
  FWTOOL=/w/openwrt/staging_dir/host/bin/fwtool
  [ -x "$FWTOOL" ] || { echo "host fwtool not found: $FWTOOL"; exit 1; }
  "$FWTOOL" -I /out/metadata-ex520.json /out/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
  echo "--- metadata in final image ---"
  "$FWTOOL" -i /tmp/meta.json /out/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
  cat /tmp/meta.json
'

echo
echo "created: $FINAL"
ls -l "$FINAL"
shasum -a 256 "$FINAL" 2>/dev/null || sha256sum "$FINAL"
echo
echo "--- tar contents ---"
tar -tvf "$TAR"
