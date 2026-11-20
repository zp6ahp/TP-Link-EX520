# TP-Link EX520 v1 — Hardware Notes

## Platform

- SoC: MediaTek MT7981BA (Filogic 820)
- RAM: 256 MiB
- Flash: 128 MiB SPI NAND, NMBM
- Switch: MT7531AE (4×LAN)
- WAN PHY: Airoha EN8801S (MDIO addr 0, GMII)
- Wi-Fi: MT7976CN DBDC (2.4 + 5 GHz)

## NAND partitions (from the U-Boot env `mtdparts`)

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

The MAC address is stored in `u-boot-env`: `labelMac=AC:A7:F1:68:B3:67`.

## LEDs

Recovered from the unstripped `tp_gpio.ko` (`tp_led_def` table, 0x30-byte
structure: `char name[4]; u8 gpio; u8 mode; u8 speed; u8 reve; ...`).
All LEDs are **active-low** (`reve = 0`), verified against the driver formula
`gpiod_set_raw_value(gpio, !value ^ reve)`.

| Name | GPIO | Function          |
|------|------|-------------------|
| POWR | 4    | power             |
| INET | 7    | internet          |
| INE2 | 5    | internet (second) |
| WL2G | 35   | Wi-Fi 2.4 GHz     |
| WL5G | 34   | Wi-Fi 5 GHz       |
| WPS  | 6    | WPS               |
| LAN  | 8    | LAN               |

The stock `etc/config.bba` has `INCLUDE_TP_GPIO_LED_DUAL_INET=y` and
`INCLUDE_TP_GPIO_LED_WL_DOUBLE=y` — hence the two internet LEDs.

## Buttons

Matches the stock DTS and the `tp_btn_def` table:

| Button | GPIO | Code          |
|--------|------|---------------|
| Reset  | 1    | KEY_RESTART   |
| WPS    | 0    | KEY_WPS_BUTTON|

Both are **active-low**.

## Notes

- MT7531 and EN8801S reset: GPIO 39 (active-high, shared).
- The real Wi-Fi calibration is stored in `misc_ro` → UBI volume `e2p`.
  Until it is extracted, `mt7981_eeprom_mt7976_dbdc.bin` is used
  (package `mt7981-eeprom-default`).
