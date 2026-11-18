# TP-Link EX520 v1 — аппаратные данные

## Платформа

- SoC: MediaTek MT7981BA (Filogic 820)
- RAM: 256 МиБ
- Flash: 128 МиБ SPI NAND, NMBM
- Switch: MT7531AE (4×LAN)
- WAN PHY: Airoha EN8801S (MDIO addr 0, GMII)
- Wi-Fi: MT7976CN DBDC (2.4 + 5 ГГц)

## Разделы NAND (из U-Boot env `mtdparts`)

| # | label        | offset    | size  |
|---|--------------|-----------|-------|
| 0 | boot         | 0x0000000 | 2 MiB |
| 1 | u-boot-env   | 0x0200000 | 1 MiB |
| 2 | misc_ro      | 0x0300000 | 6 MiB |
| 3 | misc_rw      | 0x0900000 | 6 MiB |
| 4 | ubi0         | 0x0F00000 | 40 MiB |
| 5 | ubi1         | 0x3700000 | 40 MiB |
| 6 | misc_rw_bak  | 0x5F00000 | 6 MiB |
| 7 | bflag        | 0x6500000 | 6 MiB |
| 8 | misc_isp     | 0x6B00000 | 6 MiB |

MAC берётся из `u-boot-env`: `labelMac=AC:A7:F1:68:B3:67`.

## Светодиоды

Восстановлено из неужатого `tp_gpio.ko` (таблица `tp_led_def`, структура 0x30 байт:
`char name[4]; u8 gpio; u8 mode; u8 speed; u8 reve; ...`).
Все светодиоды **active-low** (`reve = 0`), проверено по формуле драйвера
`gpiod_set_raw_value(gpio, !value ^ reve)`.

| Имя  | GPIO | Назначение        |
|------|------|-------------------|
| POWR | 4    | питание           |
| INET | 7    | интернет          |
| INE2 | 5    | интернет (второй) |
| WL2G | 35   | Wi-Fi 2.4 ГГц     |
| WL5G | 34   | Wi-Fi 5 ГГц       |
| WPS  | 6    | WPS               |
| LAN  | 8    | LAN               |

В стоковом `etc/config.bba`: `INCLUDE_TP_GPIO_LED_DUAL_INET=y`,
`INCLUDE_TP_GPIO_LED_WL_DOUBLE=y` — отсюда два «интернет»-светодиода.

## Кнопки

Совпадают со стоковым DTS и таблицей `tp_btn_def`:

| Кнопка | GPIO | Код          |
|--------|------|--------------|
| Reset  | 1    | KEY_RESTART  |
| WPS    | 0    | KEY_WPS_BUTTON |

Обе **active-low**.

## Прочее

- Reset MT7531 и EN8801S: GPIO 39 (active-high, общий).
- Реальная калибровка Wi-Fi лежит в `misc_ro` → UBI-том `e2p`.
  До её получения используется `mt7981_eeprom_mt7976_dbdc.bin`
  (пакет `mt7981-eeprom-default`).
