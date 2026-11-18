# Исходники: TP-Link EX520 v1 для OpenWrt

Поддержка устройства в mainline OpenWrt. Базовый коммит: `bb8054e`.

## Состав

- `patches/openwrt-ex520-v1.patch` — все изменения относительно mainline:
  - новый DTS `mt7981b-tplink-ex520.dts`;
  - запись в `filogic.mk`;
  - `01_leds`, `02_network`, `11_fix_wifi_mac`;
  - `platform.sh` (sysupgrade для UBI);
  - новый пакет `package/firmware/mt7981-eeprom-default`
    (generic EEPROM + автоподхват `e2p` + `fw_env.config` + LuCI ucode fix).
- `files/` — те же файлы в виде overlay (для просмотра/ручного копирования).
- `build/` — Dockerfile и скрипты сборки.
- `config.seed` — минимальный конфиг.

## Сборка через Docker

Нужны Docker (Linux/macOS с Colima/Docker Desktop) и ~10 ГБ свободного места.

```bash
cd src

# 1. Собрать образ сборщика (один раз)
docker build -t ex520-builder:24.04 build

# 2. Собрать прошивку
./build/build.sh
```

Скрипт:
1. создаёт docker-том `owrt-ex520-build`;
2. клонирует OpenWrt и переключается на `bb8054e`;
3. применяет `patches/openwrt-ex520-v1.patch`;
4. ставит фиды `luci` и `packages` (`cgi-io`, `luasrcdiet`);
5. применяет `config.seed` и собирает;
6. копирует образы в `../bin/`;
7. собирает `...-sysupgrade-final.bin` и добавляет metadata через host-`fwtool`.

## Сборка вручную (без Docker-скрипта)

```bash
git clone https://github.com/openwrt/openwrt.git
cd openwrt
git checkout bb8054e
git apply --binary ../patches/openwrt-ex520-v1.patch

./scripts/feeds update luci packages
./scripts/feeds install -a -p luci
./scripts/feeds install cgi-io luasrcdiet

cp ../config.seed .config
make defconfig
make -j"$(nproc)"
```

Результат — в `bin/targets/mediatek/filogic/`.

`...-sysupgrade-final.bin` собирается скриптом
`build/make-sysupgrade-tar.sh` из `...-squashfs-sysupgrade.bin`:
он добавляет `CONTROL` и metadata-блок `fwtool`.

## Что важно

- `u-boot-env` сделан записываемым — нужен для `fw_setenv bootcmd`
  при `sysupgrade`.
- `misc_ro` остаётся read-only: UBI attach идёт в read-only режиме,
  калибровка только читается.
- `boot` не трогается.
- Образ калибровки — generic MT7981/MT7976; реальный `e2p` каждого
  устройства подхватывается из `misc_ro` при boot.

## Проверка патча

```bash
git apply --check --binary patches/openwrt-ex520-v1.patch
```

## Лицензия

См. `LICENSE`.
