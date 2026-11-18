# EX520: TFTP-загрузка initramfs и снятие `misc_ro`

Инструкция для macOS на Apple Silicon. Все команды можно копировать в Terminal.
Перед выключением Wi-Fi сохраните этот файл или держите его открытым в редакторе.

> **Главное правило:** мы **не пишем во flash**. Initramfs живёт в RAM.
> Единственное чтение flash — `dd if=/dev/mtd2` (read-only).
> Никаких `sysupgrade`, `mtd write`, `mtd erase`, `ubiformat`, `ubiattach`.

---

## 0. Что понадобится

- Mac с Apple Silicon.
- UART-адаптер 3.3 В, уже подключён к роутеру (115200 8N1, GND/TX/RX, VCC не подключать).
- Ethernet-кабель из LAN-порта роутера в Ethernet-адаптер Mac.
- Питание роутера.
- Образ:
  `/Users/evgeniy/Documents/Dev/EX520/build/out/openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin`
  sha256: `e4605124cd845a58cc166a93e45f665b1a96f3ccaa069189899a4f8228fd69e1`

Проверить sha256:

```bash
shasum -a 256 /Users/evgeniy/Documents/Dev/EX520/build/out/openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
```

---

## 1. Кладём образ в TFTP-каталог macOS

```bash
sudo mkdir -p /private/tftpboot
sudo cp /Users/evgeniy/Documents/Dev/EX520/build/out/openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin /private/tftpboot/ex520.itb
sudo chmod 755 /private/tftpboot
sudo chmod 644 /private/tftpboot/ex520.itb
```

Проверяем, что скопировалось правильно:

```bash
shasum -a 256 /private/tftpboot/ex520.itb
```

Должен быть тот же `e4605124...`.

---

## 2. Включаем встроенный TFTP-сервер macOS

```bash
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
```

Если пишет `service already loaded` — это нормально.

Проверяем:

```bash
sudo launchctl list | grep -i tftp
```

Локальный тест (необязательно, но полезно):

```bash
cd /tmp
rm -f ex520-test.itb
tftp 127.0.0.1
```

В приглашении `tftp>`:

```text
binary
get ex520.itb
quit
```

Затем:

```bash
shasum -a 256 /tmp/ex520-test.itb
```

Если локальный тест не работает — TFTP-сервер не запущен или файл недоступен.
Если macOS спрашивает про firewall — разрешите входящие для `tftpd`.

---

## 3. Настраиваем Ethernet на Mac

Смотрим список интерфейсов:

```bash
networksetup -listallhardwareports
```

Ищите строку вроде `Hardware Port: USB 10/100/1000 LAN` или `Ethernet`.
Запоминайте `Device: enX` (например, `en5`, `en6`, `en0`).

Ставим статический IP 192.168.1.2:

```bash
sudo ifconfig enX 192.168.1.2 netmask 255.255.255.0 up
```

Проверяем:

```bash
ifconfig enX | grep "inet "
```

Должно быть `inet 192.168.1.2`.

> Если на этом же интерфейсе был интернет — он временно пропадёт.
> Для теста лучше отдельный USB-Ethernet адаптер.

Вернуть DHCP потом:

```bash
sudo networksetup -setdhcp "USB 10/100/1000 LAN"
```

(подставьте точное имя из `listallhardwareports`).

---

## 4. Подключаемся к UART

Смотрим, какие serial-устройства есть:

```bash
ls /dev/cu.*
```

Обычно что-то вроде `/dev/cu.usbserial-1420` или `/dev/cu.wchusbserial1420`.

Запускаем `screen`:

```bash
screen /dev/cu.usbserial-XXXX 115200
```

Выход из `screen`: `Ctrl-A`, затем `K`, затем `y`.

Если `screen` не нравится, можно `picocom`:

```bash
brew install picocom
picocom -b 115200 /dev/cu.usbserial-XXXX
```

Выход: `Ctrl-A`, затем `Ctrl-X`.

---

## 5. Останавливаем U-Boot

1. Включаем питание роутера.
2. Сразу многократно нажимаем `Enter` (или `Ctrl-C`) в UART-терминале.
3. Если появилось меню загрузки:
   ```
   *** U-Boot Boot Menu ***
   0. U-Boot console
   ...
   ```
   выбираем `0` и `Enter`.
4. Должен появиться prompt `MT7981>` или `U-Boot>`.

Если не успели — выключите питание и повторите, нажимая клавишу ещё раньше.

---

## 6. Проверяем сеть в U-Boot

В консоли U-Boot:

```text
printenv ipaddr serverip netmask
```

Должно быть примерно:

```text
ipaddr=192.168.1.1
serverip=192.168.1.2
netmask=255.255.255.0
```

Если нет — задаём:

```text
setenv ipaddr 192.168.1.1
setenv serverip 192.168.1.2
setenv netmask 255.255.255.0
```

Проверка связи (может не работать из-за firewall macOS — это не критично):

```text
ping 192.168.1.2
```

---

## 7. Загружаем initramfs по TFTP

```text
tftpboot 0x46000000 ex520.itb
```

Ждём. Должно быть что-то вроде:

```text
Using ethernet@15100000 device
TFTP from server 192.168.1.2; our IP address is 192.168.1.1
Filename 'ex520.itb'.
Load address: 0x46000000
Loading: ################################################
Bytes transferred = ...
```

Затем:

```text
bootm 0x46000000
```

Ядро распаковывается в `0x48000000` (перекрытия с FIT нет).

---

## 8. Что должно быть в логе загрузки

Ищем:

```text
Machine model: TP-Link EX520 v1
mt7530-mdio ... MediaTek MT7531 PHY
mtk_soc_eth ... Airoha EN8801S
mt7915e ...
```

Если загрузка остановилась — скопируйте последние 30–50 строк.

---

## 9. После загрузки: консоль роутера

Нажмите `Enter`. Должен появиться shell:

```text
root@OpenWrt:~#
```

Если просит пароль — просто `Enter` (пароль пустой).

Проверяем:

```sh
ip a
cat /proc/mtd
```

LAN должен быть `192.168.1.1`.
`mtd2` должен быть `misc_ro` размером `0x00600000`.

---

## 10. LuCI в браузере

На Mac откройте:

```text
http://192.168.1.1
```

Логин: `root`, пароль пустой. LuCI может сразу попросить задать пароль —
задайте временный, например `ex520test` (он только в RAM).

Если LuCI не открывается, в UART-консоли выполните вручную:

```sh
uci delete uhttpd.main.lua_prefix
uci add_list uhttpd.main.ucode_prefix='/cgi-bin/luci=/usr/share/ucode/luci/uhttpd.uc'
uci commit uhttpd
/etc/init.d/uhttpd restart
```

И проверьте:

```sh
logread | grep -i uhttpd
```

---

## 11. Проверка светодиодов

Список:

```sh
ls /sys/class/leds/
```

Должны быть `green:power`, `green:lan`, `green:internet`,
`green:wlan2g`, `green:wlan5g`, `green:wps`.

Включить/выключить LAN-светодиод:

```sh
echo 1 > /sys/class/leds/green:lan/brightness
echo 0 > /sys/class/leds/green:lan/brightness
```

Power должен гореть, LAN — реагировать на кабель.

---

## 12. Проверка кнопок

```sh
cat /proc/bus/input/devices
```

Ищем `gpio-keys` и кнопки `reset`, `wps`.

Посмотреть события:

```sh
ls /dev/input/
hexdump /dev/input/event0
```

Нажмите WPS (коротко). В консоли пойдут байты. Остановить: `Ctrl-C`.
Reset долго не держите.

---

## 13. Проверка WAN (если есть второй кабель)

Подключите WAN-порт роутера к upstream-роутеру/ISP.

В консоли:

```sh
ip a
logread | grep -i wan
dmesg | grep -i en8801
```

WAN должен получить адрес по DHCP или хотя бы поднять линк.

---

## 14. Проверка Wi-Fi

В LuCI: `Network → Wireless`. Должны быть два радио (2.4 и 5 ГГц).

Или в консоли:

```sh
iw dev
wifi status
dmesg | grep -i mt7915
```

Можно создать тестовую точку доступа и подключить телефон.
Помните: сейчас используется generic EEPROM, калибровка ещё не родная.

---

## 15. Снимаем `misc_ro` на Mac

### Терминал №1 — UART (роутер)

Оставляем открытым.

### Терминал №2 — Mac (приёмник)

Откройте **новое** окно Terminal (не закрывая UART).

```bash
mkdir -p /Users/evgeniy/Documents/Dev/EX520/dumps
/usr/bin/nc -l 9999 > /Users/evgeniy/Documents/Dev/EX520/dumps/misc_ro.bin
```

`nc` будет ждать. Если macOS спросит про firewall — разрешите.

### Снова Терминал №1 (роутер)

```sh
cat /proc/mtd
dd if=/dev/mtd2 bs=64k | nc 192.168.1.2 9999
```

Ждём несколько секунд, пока команда не вернёт prompt.

### Проверка на Mac (Терминал №2)

`nc` должен завершиться. Если не завершился — нажмите `Ctrl-C`
только после того, как размер файла стал правильным.

```bash
stat -f%z /Users/evgeniy/Documents/Dev/EX520/dumps/misc_ro.bin
xxd -l 16 /Users/evgeniy/Documents/Dev/EX520/dumps/misc_ro.bin
```

Ожидаем:

- размер `6291456` (6 МиБ);
- первые байты `5542 4923` (`UBI#`).

Если размер 0 или магия не та — повторите, убедившись, что `nc` на Mac
запущен **до** команды на роутере.

---

## 16. Дополнительные дампы (по желанию)

`u-boot-env` (1 МиБ):

```bash
/usr/bin/nc -l 9998 > /Users/evgeniy/Documents/Dev/EX520/dumps/u-boot-env.bin
```

На роутере:

```sh
dd if=/dev/mtd1 bs=64k | nc 192.168.1.2 9998
```

`ubi0` (40 МиБ, стоковая прошивка, дольше):

```bash
/usr/bin/nc -l 9997 > /Users/evgeniy/Documents/Dev/EX520/dumps/ubi0.bin
```

На роутере:

```sh
dd if=/dev/mtd4 bs=64k | nc 192.168.1.2 9997
```

`dmesg`:

```bash
/usr/bin/nc -l 9996 > /Users/evgeniy/Documents/Dev/EX520/dumps/dmesg.txt
```

На роутере:

```sh
dmesg | nc 192.168.1.2 9996
```

---

## 17. Выключение и восстановление Mac

На роутере:

```sh
poweroff
```

Или просто выключите питание после появления сообщения о завершении.
Во flash ничего не записано.

На Mac верните Ethernet на DHCP:

```bash
sudo networksetup -setdhcp "USB 10/100/1000 LAN"
```

И включите Wi-Fi обратно.

---

## 18. Что прислать/сохранить

Главное — файл:

```text
/Users/evgeniy/Documents/Dev/EX520/dumps/misc_ro.bin
```

Он уже лежит в проекте, я смогу его прочитать.

Дополнительно полезно:

```text
/Users/evgeniy/Documents/Dev/EX520/dumps/dmesg.txt
/Users/evgeniy/Documents/Dev/EX520/dumps/u-boot-env.bin
```

И observations:
- горят ли светодиоды;
- видны ли кнопки;
- поднялся ли WAN;
- появились ли радио 2.4/5 ГГц;
- открылся ли LuCI.

---

## 19. Если что-то пошло не так

### TFTP: `File not found`

- Проверьте имя: ровно `ex520.itb`.
- Проверьте:
  ```bash
  ls -l /private/tftpboot/ex520.itb
  ```
- Проверьте права `644`.
- Убедитесь, что TFTP-сервер запущен:
  ```bash
  sudo launchctl list | grep -i tftp
  ```

### TFTP: timeout

- Проверьте IP Mac: `ifconfig enX | grep "inet "`.
- Проверьте `serverip` в U-Boot: `printenv serverip`.
- Проверьте кабель: LAN-порт роутера, не WAN.
- Отключите firewall macOS на время теста.
- Попробуйте `tftpboot` ещё раз.

### U-Boot не останавливается

- Выключите питание.
- Включите и сразу зажмите/часто нажимайте `Enter`.
- В меню выберите `0. U-Boot console`.

### `bootm` пишет `Bad Magic Number`

- Образ повреждён или скачался не полностью.
- Проверьте sha256 на Mac и повторите `tftpboot`.

### Нет LAN / не пингуется 192.168.1.1

- Кабель в LAN-порт (не WAN).
- `ip a` на роутере.
- `ifconfig enX` на Mac.
- Попробуйте другой LAN-порт.

### LuCI не открывается

Выполните вручную:

```sh
uci delete uhttpd.main.lua_prefix
uci add_list uhttpd.main.ucode_prefix='/cgi-bin/luci=/usr/share/ucode/luci/uhttpd.uc'
uci commit uhttpd
/etc/init.d/uhttpd restart
```

Проверьте:

```sh
logread | grep -i uhttpd
netstat -lntp | grep 80
```

### `nc`: `Connection refused`

- Сначала запустите `nc -l` на Mac, потом команду на роутере.
- Проверьте firewall macOS.
- Проверьте, что Mac и роутер в одной подсети (`192.168.1.x`).

### `nc` завис

- Проверьте `ping 192.168.1.2` с роутера.
- Попробуйте другой порт (9990) и поменяйте команду.
- Убедитесь, что на Mac не занят порт:
  ```bash
  lsof -nP -iTCP:9999
  ```

---

## 20. Напоминание по безопасности

- Только чтение flash: `dd if=/dev/mtd2`.
- Не выполнять `sysupgrade`, `mtd write`, `mtd erase`, `ubiformat`, `ubiattach`.
- Не выключать питание во время записи (мы ничего не пишем).
- Если случайно запустили запись — сразу остановитесь и сообщите.
