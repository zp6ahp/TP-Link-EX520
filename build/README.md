# TP-Link EX520 — сборка и первый запуск OpenWrt

## 1. Сборка

```bash
cd /Users/evgeniy/Documents/Dev/EX520
./build/build-initramfs.sh
```

Скрипт:
- поднимает контейнер `ex520-builder:24.04` (Ubuntu 24.04 + зависимости OpenWrt);
- кладёт дерево OpenWrt (коммит из `openwrt-src`) в docker-том `owrt-ex520`;
- накладывает правки EX520 (DTS, `filogic.mk`, `01_leds`, `02_network`, MAC Wi-Fi, `platform.sh`, пакет EEPROM);
- собирает образ;
- автоматически собирает sysupgrade tar с metadata (`...-sysupgrade-final.bin`);
- складывает результат в `build/out/`.

Файлы:

- initramfs:
  `build/out/openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin`
  (sha256 `4a3ac2c99aea27de4b88d9f8b4cda4887f2ab7c90ee78adde52d78bb5368a3de`)
- установочный/обновляемый образ:
  `build/out/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin`
  (10 011 933 байт, sha256 `4b4652977f720be3ade6f18b493e39f89de33e83e6cad3e51dbbf9e589830b0a`)

**Полная инструкция по установке: `../INSTALL.md`.**

Состав образа: базовый OpenWrt + `dropbear`, `dnsmasq`, `firewall4`,
`wpad-basic-mbedtls`, `mt76`, LED/кнопки, `mt7981-eeprom-default`,
**LuCI** (`luci`, `luci-app-firewall`, `luci-theme-bootstrap`, `uhttpd`)
и **relayd** (`relayd`, `luci-proto-relay`) для режима репитера.
VPN, Samba, Docker и прочих тяжёлых пакетов нет.

Пересобрать после правок — просто запустить скрипт снова (дерево и кэш компиляции сохраняются).
Не редактируйте скрипт во время его работы: bash дочитывает файл с диска и может выполнить
испорченную строку.

## 2. Загрузка по TFTP (flash не трогаем)

На Mac (или ПК), подключённом к **LAN-порту** роутера:

```bash
# macOS: встроенный tftp-сервер, файлы кладём в /private/tftpboot
sudo mkdir -p /private/tftpboot
sudo cp build/out/openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin \
        /private/tftpboot/ex520.itb
sudo chmod 644 /private/tftpboot/ex520.itb
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
sudo ifconfig en0 alias 192.168.1.2 netmask 255.255.255.0   # подставьте свой интерфейс
```

В консоли U-Boot (115200 8N1):

```
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.2
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Ожидаемо в логе:
- `Machine model: TP-Link EX520 v1`
- `mt7530-mdio ... lan1..lan4 ... MediaTek MT7531 PHY`
- `mtk_soc_eth ... wan ... Airoha EN8801S` (или `Generic PHY`, если драйвер не взял ID)
- `mt7981-wmac` / `mt7915e` без ошибок калибровки

Проверка после загрузки (initramfs, flash не трогаем):
- горят/управляются светодиоды: power, LAN, WAN/Internet, 2.4G, 5G, WPS;
- кнопки: `Reset` и `WPS` видны в `evtest` / `cat /proc/bus/input/devices`;
- LAN-порты получают адрес по DHCP, WAN-линк поднимается;
- LuCI открывается по адресу `http://192.168.1.1` (пароль root пустой —
  при первом входе LuCI предложит его задать).

Восстановление: выключить питание — в flash ничего не записано.

## 3. Дамп разделов (после загрузки OpenWrt)

SSH в initramfs требует пароля, поэтому проще netcat. На Mac:

```bash
nc -l 9999 > misc_ro.bin
```

В консоли роутера (или по SSH, если задали пароль):

```sh
cat /proc/mtd                 # сверить имена/размеры
dd if=/dev/mtd2 bs=64k | nc 192.168.1.2 9999
```

`mtd2` = `misc_ro` (6 МБ). Это UBI-раздел: стоковая прошивка монтирует
том `misc_ro` как UBIFS, а драйвер `mt_wifi.ko` ищет в нём файл
`/var/run/misc/misc_ro/0x003A0000` — это и есть индивидуальная
калибровка Wi-Fi (`e2p`). Из дампа её достанем офлайн через `ubireader`.

Дополнительно полезно снять:

```sh
dd if=/dev/mtd1 bs=64k | nc 192.168.1.2 9998    # u-boot-env
dd if=/dev/mtd4 bs=64k | nc 192.168.1.2 9997    # ubi0 (стоковая прошивка)
```

## 4. Что дальше

1. Проверить LAN/WAN/Wi-Fi и LuCI на initramfs.
2. Разобрать `misc_ro.bin` (`ubireader_extract_files`), достать `e2p`.
3. Добавить универсальный скрипт: при первом boot вытаскивать `e2p`
   из `misc_ro` **каждого** роутера в
   `/lib/firmware/updates/mediatek/mt7981_eeprom_mt7976_dbdc.bin`.
   Тогда образ можно тиражировать, не зашивая чужую калибровку.
4. ~~Определить GPIO светодиодов и добавить их в DTS.~~ Готово: GPIO
   восстановлены из `tp_gpio.ko`, все светодиоды active-low, кнопки уже были.
5. ~~Добавить LuCI и relayd.~~ Готово.
6. Решить схему постоянной установки (запись OpenWrt в `ubi0` / замена
   загрузчика в разделе `boot`) и добавить `sysupgrade`.
