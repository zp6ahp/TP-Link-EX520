# TP-Link EX520 v1 — OpenWrt

Unofficial OpenWrt build for **TP-Link EX520 v1** (AX3000):
MediaTek MT7981BA + MT7531AE + MT7976CN + Airoha EN8801S.

> **TP-Link EX520 v1 only.**
> Not for EX520v or any other model/revision.

Languages: [Русский](README.ru.md) · [English](README.en.md) · [Español](README.es.md)

---

## 1. Purpose

This firmware replaces the stock TP-Link firmware with mainline OpenWrt and
reproduces the router's basic functionality:

- LAN ↔ WAN routing, NAT, DHCP, DNS, firewall;
- Wi-Fi 6 (2.4 + 5 GHz, MT7976 DBDC);
- 4 LAN ports, WAN port;
- LEDs and buttons (Reset, WPS);
- LuCI web interface and SSH;
- Wi-Fi repeater mode (`relayd` is installed).

The firmware **does not** reproduce TP-Link Cloud, EasyMesh, the vendor mobile
app, or other proprietary TP-Link services.

---

## 2. Features

| Feature | Status |
|---|---|
| LAN 4×1G (MT7531) | works |
| WAN (EN8801S) | link verified at 1G; 2.5G depends on peer/driver |
| Wi-Fi 6 2.4/5 GHz | works, per-device factory calibration |
| NAT/DHCP/DNS/firewall4 | works |
| LuCI | works |
| SSH (dropbear) | works |
| Wi-Fi repeater | `relayd` + `luci-proto-relay` installed |
| LEDs | 7, active-low |
| Buttons | Reset (GPIO1), WPS (GPIO0) |
| Reset → factory reset | long press ≥5 seconds |
| `sysupgrade` | tar with metadata, via LuCI/SSH |

### Wi-Fi calibration

The image does **not** contain a calibration for one specific router. On boot,
the `mt7981-eeprom` script reads `e2p` from the `misc_ro` partition of **that
device** and places it in `/lib/firmware/updates/mediatek/`. The same image can
therefore be installed on different EX520 v1 units; each keeps its own
calibration.

---

## 3. Limitations and warning

> **This is a base router firmware, not a home server.**
> It reproduces the factory functionality: routing, Wi-Fi, LAN/WAN, LEDs,
> buttons, LuCI and the repeater.
>
> **Do not install VPN servers/clients, AdGuard, Samba, Docker, torrent
> clients, media servers, or other heavy services.**
> The router has **256 MB RAM** and only about **21 MB** of usable overlay.
> Such packages easily cause OOM, spontaneous reboots, Wi-Fi failures, and
> flash exhaustion.

### 3.1. Hardware limits

- RAM: 256 MB.
- Flash: 128 MB SPI NAND, ~21 MB usable overlay.
- Wi-Fi: MT7976CN DBDC (2.4 + 5 GHz).
- WAN: EN8801S; link verified at 1G, 2.5G depends on the peer and driver.
- No official `factory.bin`: the first install requires TFTP initramfs +
  `sysupgrade`; the stock TP-Link web UI will not accept OpenWrt.

### 3.2. Not supported

- TP-Link Cloud, EasyMesh, TP-Link mobile app.
- "All-in-one" images with VPN/AdGuard/Samba/Docker.
- Installation through the stock TP-Link web UI.
- EX520v and other revisions.

### 3.3. How to monitor whether extra modules will destabilize the system

Check the baseline **before** installing a package, **right after**, and
**after a reboot**. If a metric gets worse, remove the last package.

#### Quick check

```sh
free -m
cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|Slab|SReclaimable|SUnreclaim'
df -h /overlay
uptime
cat /proc/loadavg
nproc
```

#### Danger signs

| Metric | Healthy | Alarm |
|---|---|---|
| `MemAvailable` | > 50 MB | < 30 MB — OOM risk |
| `SUnreclaim` | stable | growing for hours — kernel/driver leak |
| `load average` | below core count | consistently > 2 on 2 cores |
| `/overlay` | < 70% | > 80% — flash nearly full |
| OOM in logs | none | present — already unstable |

#### Logs

```sh
dmesg | grep -iE 'oom|out of memory|killed process|mt76.*(error|fail|stuck)'
logread | grep -iE 'oom|out of memory|killed process|mt76.*(error|fail)'
```

#### Who is using memory

```sh
top -b -n1 | head -20
ps w
```

In LuCI: **Status → Overview**, **Status → Realtime Graphs**,
**Status → Processes**.

#### Finding the culprit

1. Record `MemAvailable`, `SUnreclaim`, `load average`, `df -h /overlay`.
2. Install **one** package and reboot.
3. Measure again.
4. If `MemAvailable` dropped noticeably, `SUnreclaim` grew, or OOM appeared,
   remove the package:

```sh
apk del <package-name>
# older builds: opkg remove <package-name>
```

5. Disable unneeded services:

```sh
/etc/init.d/<service> stop
/etc/init.d/<service> disable
```

6. If Wi-Fi starts dropping under load, check memory and `dmesg` for
   `mt76`/`ieee80211` issues first, not just the channel.

---

## 4. Installation

### 4.1. Files

In the `bin/` folder:

```
openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
INSTALL.md
SHA256SUMS
recovery/ubi0.bin          (optional, for recovery)
```

Hashes for this release:

```
initramfs: 4a3ac2c99aea27de4b88d9f8b4cda4887f2ab7c90ee78adde52d78bb5368a3de
sysupgrade: 4b4652977f720be3ade6f18b493e39f89de33e83e6cad3e51dbbf9e589830b0a
ubi0:      a89574da99e4d00a19c1c7127db082986d45bf73e1115f2119b9ff6cb190083d
```

Verify (macOS/Linux):

```bash
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

Windows (PowerShell):

```powershell
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin -Algorithm SHA256
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin -Algorithm SHA256
```

The second file is a tar container (`kernel` + `root` + `CONTROL`) with
metadata. `sysupgrade` accepts it without `-F`; LuCI does too.

### 4.2. Requirements

- EX520 v1 router and power supply.
- 3.3 V UART, 115200 8N1 (GND/TX/RX, do not connect VCC).
- Ethernet cable: router LAN port ↔ PC network adapter.
- TFTP server on the PC for the initramfs.
- HTTP server on the PC for `-final.bin`.
- PC at `192.168.1.2/24`; the router is `192.168.1.1` in U-Boot.

---

### 4.3. Installation on Windows

#### Step 1. TFTP

1. Download and start **Tftpd64** (or Tftpd32).
2. Open the **TFTP** tab.
3. `Current Directory` — the folder containing `ex520.itb`.
4. `Server Interface` — the adapter with `192.168.1.2`.
5. Click **Start**.

#### Step 2. Network and UART

1. Connect the cable to the router's **LAN port**.
2. Set the Windows adapter to `192.168.1.2`, mask `255.255.255.0`.
3. Start PuTTY/Tera Term: USB-UART COM port, `115200`, 8N1, no flow control.

#### Step 3. Boot the initramfs

Power on the router and stop U-Boot (`Enter`/`Ctrl-C`; if a menu appears,
choose `0. U-Boot console`).

In UART:

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Wait for `root@OpenWrt:~#`.

#### Step 4. HTTP server

In a Windows command prompt, change to the folder with `-final.bin`:

```powershell
cd C:\path\to\bin
py -m http.server 8000
```

If Python is not installed, install it from python.org or use any simple HTTP
server rooted in that folder.

Check in a browser: `http://192.168.1.2:8000/` — the file list should appear.

#### Step 5. Install

In UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

The router downloads the image, validates the metadata, writes the UBI volumes,
and reboots.

**Do not power off.**

---

### 4.4. Installation on macOS

#### Step 1. TFTP

```bash
cd /path/to/bin
sudo cp openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin /private/tftpboot/ex520.itb
sudo chmod 644 /private/tftpboot/ex520.itb
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
```

If `launchctl` complains, the service is usually already running. Verify:

```bash
cd /tmp
tftp 127.0.0.1
```

At the `tftp>` prompt:

```text
binary
get ex520.itb
quit
```

#### Step 2. Network and UART

```bash
networksetup -listallhardwareports
sudo ifconfig enX 192.168.1.2 netmask 255.255.255.0 up
ls /dev/cu.*
screen /dev/cu.usbserial-XXXX 115200
```

Exit `screen`: `Ctrl-A`, then `K`, then `y`.

#### Step 3. Boot the initramfs

Power on the router and stop U-Boot.

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Wait for `root@OpenWrt:~#`.

#### Step 4. HTTP server

In a second Terminal window:

```bash
cd /path/to/bin
python3 -m http.server 8000
```

Check: `http://192.168.1.2:8000/`.

#### Step 5. Install

In UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

**Do not power off.**

---

### 4.5. After installation

```sh
ip a
mount | grep overlay
df -h
dmesg | grep mt7981-eeprom
```

Expected:
- LAN `192.168.1.1`;
- overlay from `rootfs_data`;
- `mt7981-eeprom: EEPROM extracted from /tmp/misc_ro/0x003A0000`;
- LuCI: `http://192.168.1.1`.

### 4.6. Updates

LuCI → **System → Backup / Flash Firmware → Flash image**,
upload the same `-final.bin`.

Or over SSH:

```sh
sysupgrade -n /tmp/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

### 4.7. Recovery

If the installation fails:

1. Boot the initramfs over TFTP (section 4.3/4.4).
2. Put `recovery/ubi0.bin` into the TFTP server folder.
3. In U-Boot:

```text
tftpboot 0x46000000 ubi0.bin
nmbm0 write 0x46000000 0xF00000 0x2800000
```

4. Power-cycle the router.

`misc_ro` (calibration), `boot`, and `u-boot-env` are not touched.

---

## 5. Wi-Fi repeater

`relayd` and `luci-proto-relay` are installed. Two options:

- **NAT repeater** — simpler: the upstream is joined as a client, the local
  network stays `192.168.1.x`, double NAT.
- **relayd** — one subnet with the upstream: clients get addresses from the
  upstream router. Disable DHCP on LAN and give the repeater a free address in
  the upstream subnet.

Detailed steps are in `bin/INSTALL.md` and in LuCI → Network.
If the upstream is also `192.168.1.x`, change the LAN to `192.168.2.1` first.

---

## 6. Building from source

Sources are in `src/`:

- `src/patches/openwrt-ex520-v1.patch` — patch for OpenWrt `bb8054e`;
- `src/files/` — overlay files;
- `src/build/build.sh` — Docker build;
- `src/README.md` — details.

Quick build:

```bash
cd src/build
./build.sh
```

The script clones OpenWrt, applies the patch, installs feeds, builds, and
creates `-final.bin` with metadata.

---

## 7. License

See `src/LICENSE`. OpenWrt is GPL-2.0; the generic EEPROM is BSD-3-Clause-Clear.
