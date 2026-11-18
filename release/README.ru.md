# TP-Link EX520 v1 — OpenWrt

Неофициальная сборка OpenWrt для **TP-Link EX520 v1** (AX3000):
MediaTek MT7981BA + MT7531AE + MT7976CN + Airoha EN8801S.

> **Только для EX520 v1.**
> Не для EX520v и не для других моделей/ревизий.

Языки: [Русский](README.ru.md) · [English](README.en.md) · [Español](README.es.md)

---

## 1. Для чего

Прошивка заменяет стоковую прошивку TP-Link на mainline OpenWrt и
воспроизводит базовый функционал роутера:

- маршрутизация LAN ↔ WAN, NAT, DHCP, DNS, firewall;
- Wi-Fi 6 (2.4 + 5 ГГц, MT7976 DBDC);
- 4 LAN-порта, WAN-порт;
- светодиоды и кнопки (Reset, WPS);
- веб-интерфейс LuCI и SSH;
- режим Wi-Fi-репитера (relayd установлен).

Прошивка **не** повторяет облако TP-Link, EasyMesh, мобильное приложение
производителя и другие проприетарные сервисы TP-Link.

---

## 2. Что может

| Возможность | Статус |
|---|---|
| LAN 4×1G (MT7531) | работает |
| WAN (EN8801S) | проверен линк 1G; 2.5G зависит от peer/драйвера |
| Wi-Fi 6 2.4/5 ГГц | работает, реальная калибровка каждого устройства |
| NAT/DHCP/DNS/firewall4 | работает |
| LuCI | работает |
| SSH (dropbear) | работает |
| Репитер Wi-Fi | relayd + `luci-proto-relay` установлены |
| Светодиоды | 7 шт., active-low |
| Кнопки | Reset (GPIO1), WPS (GPIO0) |
| Reset → factoryreset | долгое удержание ≥5 сек |
| `sysupgrade` | tar с metadata, обновление через LuCI/SSH |

### Калибровка Wi-Fi

В образ **не** зашита калибровка конкретного роутера. При boot скрипт
`mt7981-eeprom` читает `e2p` из раздела `misc_ro` **этого** устройства и
кладёт его в `/lib/firmware/updates/mediatek/`. Поэтому один и тот же
образ можно ставить на разные EX520 v1 — у каждого будет своя калибровка.

---

## 3. Ограничения и предупреждение

> **Это базовая прошивка роутера, а не домашний сервер.**
> Она повторяет заводской функционал: маршрутизация, Wi-Fi, LAN/WAN,
> светодиоды, кнопки, LuCI и репитер.
>
> **Не устанавливайте VPN-серверы/клиенты, AdGuard, Samba, Docker,
> торрент-клиенты, медиасерверы и другие тяжёлые сервисы.**
> В роутере **256 МБ RAM** и всего около **21 МБ** доступного overlay.
> Такие пакеты легко приводят к OOM, самопроизвольным перезагрузкам,
> падению Wi-Fi и переполнению flash.

### 3.1. Аппаратные ограничения

- RAM: 256 МБ.
- Flash: 128 МБ SPI NAND, полезный overlay ~21 МБ.
- Wi-Fi: MT7976CN DBDC (2.4 + 5 ГГц).
- WAN: EN8801S; линк проверен на 1G, 2.5G зависит от собеседника и драйвера.
- Нет официального `factory.bin`: первая установка — только через
  TFTP initramfs + `sysupgrade`, стоковая веб-морда OpenWrt не примет.

### 3.2. Что не поддерживается

- Облако TP-Link, EasyMesh, приложение TP-Link.
- Готовые «всё в одном» образы с VPN/AdGuard/Samba/Docker.
- Установка через стоковую веб-морду TP-Link.
- EX520v и другие ревизии.

### 3.3. Как отслеживать, что дополнительные модули скоро уронят систему

Проверяйте состояние **до** установки пакета, **сразу после** и **после
перезагрузки**. Если показатель ухудшился — удалите последний пакет.

#### Быстрая проверка

```sh
free -m
cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|Slab|SReclaimable|SUnreclaim'
df -h /overlay
uptime
cat /proc/loadavg
nproc
```

#### Признаки опасности

| Показатель | Норма | Тревога |
|---|---|---|
| `MemAvailable` | > 50 МБ | < 30 МБ — риск OOM |
| `SUnreclaim` | стабильный | растёт часами — утечка в ядре/драйвере |
| `load average` | < числа ядер | стабильно > 2 при 2 ядрах |
| `/overlay` | < 70% | > 80% — flash почти полон |
| OOM в логах | нет | есть — система уже нестабильна |

#### Логи

```sh
dmesg | grep -iE 'oom|out of memory|killed process|mt76.*(error|fail|stuck)'
logread | grep -iE 'oom|out of memory|killed process|mt76.*(error|fail)'
```

#### Кто ест память

```sh
top -b -n1 | head -20
ps w
```

В LuCI: **Status → Overview**, **Status → Realtime Graphs**,
**Status → Processes**.

#### Как найти виновника

1. Запишите `MemAvailable`, `SUnreclaim`, `load average`, `df -h /overlay`.
2. Установите **один** пакет и перезагрузитесь.
3. Снова снимите показатели.
4. Если `MemAvailable` упал заметно, `SUnreclaim` вырос или появились OOM —
   удалите пакет:

```sh
apk del <имя-пакета>
# в старых сборках: opkg remove <имя-пакета>
```

5. Отключите ненужные сервисы:

```sh
/etc/init.d/<service> stop
/etc/init.d/<service> disable
```

6. Если Wi-Fi начал «отваливаться» под нагрузкой, сначала проверьте память
   и `dmesg` на `mt76`/`ieee80211`, а не только канал.

---

## 4. Установка

### 4.1. Файлы

В папке `bin/`:

```
openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
INSTALL.md
SHA256SUMS
recovery/ubi0.bin          (опционально, для восстановления)
```

Хэши для этого релиза:

```
initramfs: 4a3ac2c99aea27de4b88d9f8b4cda4887f2ab7c90ee78adde52d78bb5368a3de
sysupgrade: 4b4652977f720be3ade6f18b493e39f89de33e83e6cad3e51dbbf9e589830b0a
ubi0:      a89574da99e4d00a19c1c7127db082986d45bf73e1115f2119b9ff6cb190083d
```

Проверка (macOS/Linux):

```bash
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

Windows (PowerShell):

```powershell
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin -Algorithm SHA256
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin -Algorithm SHA256
```

Второй файл — tar-контейнер (`kernel` + `root` + `CONTROL`) с metadata.
`sysupgrade` принимает его без `-F`; LuCI тоже.

### 4.2. Что нужно

- Роутер EX520 v1 и питание.
- UART 3.3 В, 115200 8N1 (GND/TX/RX, VCC не подключать).
- Ethernet-кабель: LAN-порт роутера ↔ сетевой адаптер ПК.
- TFTP-сервер на ПК для initramfs.
- HTTP-сервер на ПК для `-final.bin`.
- ПК с адресом `192.168.1.2/24`; роутер в U-Boot тоже `192.168.1.1`.

---

### 4.3. Установка на Windows

#### Шаг 1. TFTP

1. Скачайте и запустите **Tftpd64** (или Tftpd32).
2. Вкладка **TFTP**.
3. `Current Directory` — папка, где лежит `ex520.itb`.
4. `Server Interface` — адаптер с адресом `192.168.1.2`.
5. Нажмите **Start**.

#### Шаг 2. Сеть и UART

1. Подключите кабель в **LAN-порт** роутера.
2. В Windows задайте адаптеру `192.168.1.2`, маска `255.255.255.0`.
3. Запустите PuTTY/Tera Term: COM-порт USB-UART, `115200`, 8N1, без flow control.

#### Шаг 3. Загрузка initramfs

Включите роутер, остановите U-Boot (`Enter`/`Ctrl-C`, при меню — `0. U-Boot console`).

В UART:

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Ждите `root@OpenWrt:~#`.

#### Шаг 4. HTTP-сервер

В командной строке Windows перейдите в папку с `-final.bin`:

```powershell
cd C:\путь\к\папке\bin
py -m http.server 8000
```

Если Python нет — поставьте с python.org или используйте любой простой
HTTP-сервер с корнем в этой папке.

Проверка в браузере: `http://192.168.1.2:8000/` — должен открыться список файлов.

#### Шаг 5. Установка

В UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

Роутер скачает образ, проверит metadata, запишет UBI и перезагрузится.

**Не выключайте питание.**

---

### 4.4. Установка на macOS

#### Шаг 1. TFTP

```bash
cd /путь/к/папке/bin
sudo cp openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin /private/tftpboot/ex520.itb
sudo chmod 644 /private/tftpboot/ex520.itb
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
```

Если `launchctl` ругается — TFTP уже запущен. Проверка:

```bash
cd /tmp
tftp 127.0.0.1
```

В `tftp>`:

```text
binary
get ex520.itb
quit
```

#### Шаг 2. Сеть и UART

```bash
networksetup -listallhardwareports
sudo ifconfig enX 192.168.1.2 netmask 255.255.255.0 up
ls /dev/cu.*
screen /dev/cu.usbserial-XXXX 115200
```

Выход из `screen`: `Ctrl-A`, затем `K`, затем `y`.

#### Шаг 3. Загрузка initramfs

Включите роутер, остановите U-Boot.

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Ждите `root@OpenWrt:~#`.

#### Шаг 4. HTTP-сервер

Во втором окне Terminal:

```bash
cd /путь/к/папке/bin
python3 -m http.server 8000
```

Проверка: `http://192.168.1.2:8000/`.

#### Шаг 5. Установка

В UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

**Не выключайте питание.**

---

### 4.5. После установки

```sh
ip a
mount | grep overlay
df -h
dmesg | grep mt7981-eeprom
```

Ожидается:
- LAN `192.168.1.1`;
- overlay из `rootfs_data`;
- `mt7981-eeprom: EEPROM extracted from /tmp/misc_ro/0x003A0000`;
- LuCI: `http://192.168.1.1`.

### 4.6. Обновления

LuCI → **System → Backup / Flash Firmware → Flash image**,
загрузить тот же `-final.bin`.

Или по SSH:

```sh
sysupgrade -n /tmp/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

### 4.7. Восстановление

Если установка не удалась:

1. Загрузите initramfs по TFTP (раздел 4.3/4.4).
2. Положите `recovery/ubi0.bin` в папку TFTP-сервера.
3. В U-Boot:

```text
tftpboot 0x46000000 ubi0.bin
nmbm0 write 0x46000000 0xF00000 0x2800000
```

4. Выключите/включите питание.

`misc_ro` (калибровка), `boot` и `u-boot-env` не затрагиваются.

---

## 5. Репитер Wi-Fi

Установлены `relayd` и `luci-proto-relay`. Два варианта:

- **NAT-репитер** — проще: upstream подключается как клиент, локальная
  сеть остаётся `192.168.1.x`, работает двойной NAT.
- **relayd** — одна подсеть с upstream: клиенты получают адреса от
  upstream-роутера. Нужно выключить DHCP на LAN и поставить роутеру
  свободный адрес в подсети upstream.

Подробные шаги — в `bin/INSTALL.md` и в разделе LuCI → Network.
Если upstream тоже `192.168.1.x`, сначала смените LAN на `192.168.2.1`.

---

## 6. Сборка из исходников

Исходники — в `src/`:

- `src/patches/openwrt-ex520-v1.patch` — патч для OpenWrt `bb8054e`;
- `src/files/` — overlay-файлы;
- `src/build/build.sh` — сборка через Docker;
- `src/README.md` — подробности.

Кратко:

```bash
cd src/build
./build.sh
```

Скрипт сам клонирует OpenWrt, применяет патч, ставит фиды, собирает и
создаёт `-final.bin` с metadata.

---

## 7. Лицензия

См. `src/LICENSE`. OpenWrt — GPL-2.0; generic EEPROM — BSD-3-Clause-Clear.
