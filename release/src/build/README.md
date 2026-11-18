# build

- `build.sh` — переносимая сборка через Docker: клонирует OpenWrt `bb8054e`,
  применяет патч, ставит фиды, собирает initramfs и sysupgrade, затем
  собирает `-final.bin` с metadata.
- `make-sysupgrade-tar.sh` — из `...-squashfs-sysupgrade.bin` делает tar
  `kernel` + `root` + `CONTROL` и добавляет metadata через host-`fwtool`.
- `Dockerfile` — окружение сборки (Ubuntu 24.04 + зависимости OpenWrt).

Подробности — в `../README.md`.

Запуск:

```bash
docker build -t ex520-builder:24.04 .
./build.sh
```

Результат — в `../../bin/`.
