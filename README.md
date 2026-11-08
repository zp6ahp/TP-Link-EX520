# TP-Link EX520 v1 — OpenWrt

Unofficial OpenWrt build for **TP-Link EX520 v1** (AX3000).

> **TP-Link EX520 v1 only.** Not for EX520v or other revisions.

## Languages / Языки / Idiomas

- [Русский](README.ru.md)
- [English](README.en.md)
- [Español](README.es.md)

## Contents

- `bin/` — ready-to-use firmware, checksums, install guide, recovery backup.
- `src/` — OpenWrt patch, overlay files, build scripts and documentation.

## Important

> This is a **base router firmware**, not a home server.
> It reproduces the factory functionality: routing, Wi-Fi, LAN/WAN, LEDs,
> buttons, LuCI and the repeater.
>
> **Do not install VPN servers/clients, AdGuard, Samba, Docker, torrent
> clients, media servers, or other heavy services.**
> The router has **256 MB RAM** and only about **21 MB** of usable overlay.
> Such packages easily cause OOM, spontaneous reboots, Wi-Fi failures, and
> flash exhaustion.
>
> See the language-specific README for monitoring commands and thresholds.

## Quick start

See `bin/INSTALL.md` or the language-specific README.
First installation: TFTP initramfs → HTTP server with `-final.bin` → `sysupgrade`.

## License GNU General Public License v2.0

Copyright (c) 2026 Evgenii Pavlov  aka ZP6AHP

