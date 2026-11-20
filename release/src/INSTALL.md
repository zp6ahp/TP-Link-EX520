# Installation — TP-Link EX520 v1

This guide covers the **first installation** from the stock TP-Link firmware.
For features, limitations, and stability monitoring, see `README.md`.

> **TP-Link EX520 v1 only.** Not for EX520v or other revisions.

> **Do not power off during the UBI write.**
> The first boot after installation may take longer while the overlay is
> created.

## Files

Download from the GitHub **Releases** page (or use the `bin/` folder from the
release package):

```
openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
SHA256SUMS
recovery/ubi0.bin          (optional, for recovery)
```

Verify the files against `SHA256SUMS`. The `-final.bin` is a tar container
(`kernel` + `root` + `CONTROL`) with metadata; `sysupgrade` accepts it without
`-F`.

## Requirements

- EX520 v1 router and power supply.
- 3.3 V UART, 115200 8N1 (GND/TX/RX, do not connect VCC).
- Ethernet cable: router LAN port ↔ PC network adapter.
- TFTP server on the PC for the initramfs.
- HTTP server on the PC for `-final.bin`.
- PC at `192.168.1.2/24`; the router is `192.168.1.1` in U-Boot.

---

## Windows

### 1. TFTP

1. Download and start **Tftpd64** (or Tftpd32).
2. Open the **TFTP** tab.
3. `Current Directory` — the folder containing `ex520.itb`.
4. `Server Interface` — the adapter with `192.168.1.2`.
5. Click **Start**.

### 2. Network and UART

1. Connect the cable to the router's **LAN port**.
2. Set the Windows adapter to `192.168.1.2`, mask `255.255.255.0`.
3. Start PuTTY/Tera Term: USB-UART COM port, `115200`, 8N1, no flow control.

### 3. Boot the initramfs

Power on the router and stop U-Boot (`Enter`/`Ctrl-C`; if a menu appears,
choose `0. U-Boot console`).

In UART:

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Wait for `root@OpenWrt:~#`.

### 4. HTTP server

In a Windows command prompt, change to the folder with `-final.bin`:

```powershell
cd C:\path\to\bin
py -m http.server 8000
```

If Python is not installed, install it from python.org or use any simple HTTP
server rooted in that folder.

Check in a browser: `http://192.168.1.2:8000/` — the file list should appear.

### 5. Install

In UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

The router downloads the image, validates the metadata, writes the UBI volumes,
and reboots. **Do not power off.**

---

## macOS

### 1. TFTP

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

### 2. Network and UART

```bash
networksetup -listallhardwareports
sudo ifconfig enX 192.168.1.2 netmask 255.255.255.0 up
ls /dev/cu.*
screen /dev/cu.usbserial-XXXX 115200
```

Exit `screen`: `Ctrl-A`, then `K`, then `y`.

### 3. Boot the initramfs

Power on the router and stop U-Boot.

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Wait for `root@OpenWrt:~#`.

### 4. HTTP server

In a second Terminal window:

```bash
cd /path/to/bin
python3 -m http.server 8000
```

Check: `http://192.168.1.2:8000/`.

### 5. Install

In UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

**Do not power off.**

---

## After installation

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

## Updates

LuCI → **System → Backup / Flash Firmware → Flash image**, upload the same
`-final.bin`.

Or over SSH:

```sh
sysupgrade -n /tmp/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

## Wi-Fi repeater

`relayd` and `luci-proto-relay` are installed. Two options.

### NAT repeater (simpler)

1. Network → Wireless → 5 GHz → Scan → Join Network:
   - upstream password;
   - firewall zone `wan`;
   - create the `wwan` interface.
2. Network → Wireless → 2.4 GHz → Add:
   - Mode: Access Point;
   - ESSID and password;
   - Network: `lan`;
   - WPA2/WPA3.
3. Network → Firewall: `wan` masquerading on, `lan` → `wan` forwarding on.
4. If the upstream is also `192.168.1.x`, change the LAN to `192.168.2.1` first.

### relayd (one subnet with the upstream)

1. Network → Interfaces → LAN:
   - IPv4 address = free address in the upstream subnet (e.g. `192.168.0.2`);
   - mask as on the upstream;
   - DHCP Server → Ignore interface.
2. Network → Wireless → 5 GHz → Scan → Join Network:
   - upstream password;
   - firewall zone `unspecified`;
   - create `wwan`.
3. Network → Interfaces → Add new interface:
   - Name: `repeater`;
   - Protocol: `Relay bridge`;
   - Relay between: `lan` and `wwan`;
   - Firewall zone: `lan`.
4. Network → Wireless → 2.4 GHz → Add: Access Point, ESSID, Network `lan`, WPA2/WPA3.
5. Verify:

   ```sh
   logread | grep -i relayd
   ubus call network.interface.repeater status
   ```

> If the upstream is also `192.168.1.x`, use a free address in that subnet
> (e.g. `192.168.1.2`) for relayd, not `192.168.1.1`.

## Recovery

If the installation fails:

1. Boot the initramfs over TFTP (see above).
2. Put `recovery/ubi0.bin` from the release package into the TFTP server folder.
3. In U-Boot:

```text
tftpboot 0x46000000 ubi0.bin
nmbm0 write 0x46000000 0xF00000 0x2800000
```

4. Power-cycle the router.

`misc_ro` (calibration), `boot`, and `u-boot-env` are not touched.
