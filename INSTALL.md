# TP-Link EX520 v1 — установка OpenWrt

Простая инструкция для первой установки OpenWrt на стоковую прошивку.
После установки обновления делаются через LuCI или SSH.

> **Только для TP-Link EX520 v1.**
> Не для EX520v и не для других моделей.

> **Не выключайте питание во время записи.**
> Первый boot после установки может занять больше времени.

---

## Что где вводить

- **Терминал 1 (UART)** — консоль роутера. Здесь выполняются команды OpenWrt/U-Boot.
- **Терминал 2 (компьютер)** — здесь запускаются TFTP-сервер и HTTP-сервер.
- На Windows вместо Терминала 2: UART-программа (PuTTY/Tera Term), Tftpd64 и командная строка/Python.

---

## 0. Файлы

Положите оба файла в одну папку, например `ex520`:

```
openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
sha256 4a3ac2c99aea27de4b88d9f8b4cda4887f2ab7c90ee78adde52d78bb5368a3de

openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
10 011 933 байт
sha256 4b4652977f720be3ade6f18b493e39f89de33e83e6cad3e51dbbf9e589830b0a
```

Второй файл — tar-контейнер (`kernel` + `root` + `CONTROL`) с расширением `.bin`.
В нём уже есть metadata-блок, поэтому `sysupgrade` принимает его **без `-F`**.
Не используйте `...-squashfs-sysupgrade.bin` из сборки — это другой формат.

Проверка хэшей (macOS/Linux):

```bash
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

Windows (PowerShell):

```powershell
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin -Algorithm SHA256
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin -Algorithm SHA256
```

---

## 1. TFTP для загрузки initramfs

### macOS

```bash
cd /путь/к/папке/ex520   # папка, где лежат файлы
sudo cp openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin /private/tftpboot/ex520.itb
sudo chmod 644 /private/tftpboot/ex520.itb
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
```

Если `launchctl` ругается — сервис, скорее всего, уже запущен. Проверка:

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

### Windows

1. Скачайте **Tftpd64** (или Tftpd32).
2. Запустите, вкладка **TFTP**.
3. `Current Directory` — папка, где лежит `ex520.itb`.
4. `Server Interface` — сетевой интерфейс с адресом **192.168.1.2**.
5. Нажмите **Start**.

---

## 2. Сеть и UART

- Кабель из **LAN-порта роутера** — в сетевой адаптер компьютера.
- На компьютере задайте адрес **192.168.1.2**, маска **255.255.255.0**.

macOS:

```bash
sudo ifconfig en7 192.168.1.2 netmask 255.255.255.0 up
```

(замените `en7` на ваш Ethernet-интерфейс).

Windows:

`Панель управления → Сеть → Свойства адаптера → IPv4 → 192.168.1.2 / 255.255.255.0`.

UART: **115200 8N1**, без flow control.
macOS: `screen /dev/cu.usbserial-XXXX 115200`.
Windows: PuTTY/Tera Term, COM-порт, 115200.

---

## 3. Загрузка initramfs (Терминал 1, UART)

Включите роутер и остановите U-Boot (`Enter`/`Ctrl-C`, при меню — `0. U-Boot console`).

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Ждите:

```text
Machine model: TP-Link EX520 v1
...
root@OpenWrt:~#
```

Если просит пароль — `Enter` (пустой).

---

## 4. HTTP-сервер с установочным файлом (Терминал 2, компьютер)

Перейдите в папку, где лежит `openwrt-...-sysupgrade-final.bin`.

macOS/Linux:

```bash
cd /путь/к/папке/ex520
python3 -m http.server 8000
```

Windows (PowerShell/CMD):

```powershell
cd C:\путь\к\папке\ex520
py -m http.server 8000
```

Если `py`/`python` не установлен — поставьте Python с python.org
или используйте любой простой HTTP-сервер с корнем в этой папке.

Сервер должен работать, пока идёт установка. Не закрывайте окно.

Проверка с компьютера (в браузере):

```text
http://192.168.1.2:8000/
```

Должен открыться список файлов, среди них `openwrt-...-sysupgrade-final.bin`.

Если не открывается — проверьте firewall: разрешите Python/порт 8000.

---

## 5. Установка (Терминал 1, UART)

Одна команда:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

Что произойдёт:

1. Роутер скачает файл по HTTP.
2. Проверит образ.
3. Пропишет `bootcmd`.
4. Пересоздаст и запишет `kernel`, `rootfs`, `rootfs_data` в `ubi0`.
5. Перезагрузится.

**Не выключайте питание.**

---

## 6. После перезагрузки

```sh
ip a
mount | grep overlay
df -h
dmesg | grep mt7981-eeprom
logread | grep mt7981-eeprom
```

Ожидается:
- LAN `192.168.1.1`, MAC `ac:a7:f1:68:b3:67`;
- overlay смонтирован из `rootfs_data`;
- строка `mt7981-eeprom: EEPROM extracted from /tmp/misc_ro/0x003A0000`;
- LuCI: `http://192.168.1.1`.

---

## 7. Обновления

В LuCI:

```
System → Backup / Flash Firmware → Flash image
```

Загружайте тот же `openwrt-...-sysupgrade-final.bin`.

Или по SSH:

```sh
sysupgrade -n /tmp/openwrt-...-sysupgrade-final.bin
```

---

## 8. Восстановление

1. Загрузите initramfs по TFTP (раздел 3).
2. Положите `ubi0.bin` в папку TFTP-сервера (рядом с `ex520.itb`).
3. В U-Boot:

```text
tftpboot 0x46000000 ubi0.bin
nmbm0 write 0x46000000 0xF00000 0x2800000
```

4. Выключите/включите питание.

`misc_ro` (калибровка Wi-Fi), `boot` и `u-boot-env` не затрагиваются.

---

## 9. Частые ошибки

### `no such file or directory`

Файл ищется в **текущей папке**. Если вы в `~`, а файл в другой папке — укажите полный путь
или сначала перейдите в папку:

```bash
cd /путь/к/папке/ex520
```

### TFTP timeout

- Кабель в LAN-порту роутера.
- IP компьютера `192.168.1.2`.
- `serverip` в U-Boot = `192.168.1.2`.
- Firewall не блокирует TFTP.

### HTTP 404 / не скачивается

- HTTP-сервер запущен **в папке с файлом**.
- Имя файла в команде `sysupgrade` совпадает.
- Firewall разрешает порт 8000.
- Телефон/другой ПК может открыть `http://192.168.1.2:8000/`.

### `Image check failed`

Используйте именно `openwrt-...-sysupgrade-final.bin`,
а не `openwrt-...-squashfs-sysupgrade.bin`.

Если используете старый образ без metadata (`...-install.bin`), нужен `sysupgrade -F`.
В `...-final.bin` metadata уже есть, `-F` не нужен.

### Калибровка Wi-Fi

При boot скрипт `mt7981-eeprom` достаёт `e2p` из `misc_ro` этого роутера.
Образ можно ставить на другие EX520 v1 — у каждого будет своя калибровка.

### Сброс к заводским настройкам

Долгое удержание **Reset** (≥5 секунд) в OpenWrt → `factoryreset` и перезагрузка.
Короткое нажатие — reboot.
