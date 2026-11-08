# TP-Link EX520 v1 — OpenWrt

Compilación no oficial de OpenWrt para **TP-Link EX520 v1** (AX3000):
MediaTek MT7981BA + MT7531AE + MT7976CN + Airoha EN8801S.

> **Solo para EX520 v1.**
> No para EX520v ni para otros modelos/revisiones.

Idiomas: [Русский](README.ru.md) · [English](README.en.md) · [Español](README.es.md)

---

## 1. Para qué sirve

Este firmware sustituye el firmware de fábrica de TP-Link por OpenWrt mainline
y reproduce la funcionalidad básica del router:

- enrutamiento LAN ↔ WAN, NAT, DHCP, DNS, firewall;
- Wi-Fi 6 (2.4 + 5 GHz, MT7976 DBDC);
- 4 puertos LAN, puerto WAN;
- LED y botones (Reset, WPS);
- interfaz web LuCI y SSH;
- modo repetidor Wi-Fi (`relayd` instalado).

El firmware **no** reproduce TP-Link Cloud, EasyMesh, la app móvil del
fabricante ni otros servicios propietarios de TP-Link.

---

## 2. Qué puede hacer

| Función | Estado |
|---|---|
| LAN 4×1G (MT7531) | funciona |
| WAN (EN8801S) | enlace verificado a 1G; 2.5G depende del peer/controlador |
| Wi-Fi 6 2.4/5 GHz | funciona, calibración real de cada equipo |
| NAT/DHCP/DNS/firewall4 | funciona |
| LuCI | funciona |
| SSH (dropbear) | funciona |
| Repetidor Wi-Fi | `relayd` + `luci-proto-relay` instalados |
| LED | 7, activos en bajo |
| Botones | Reset (GPIO1), WPS (GPIO0) |
| Reset → factory reset | pulsación larga ≥5 s |
| `sysupgrade` | tar con metadata, por LuCI/SSH |

### Calibración Wi-Fi

La imagen **no** incluye la calibración de un router concreto. Al arrancar, el
script `mt7981-eeprom` lee `e2p` de la partición `misc_ro` de **ese** equipo y
lo copia a `/lib/firmware/updates/mediatek/`. Por eso la misma imagen se puede
instalar en distintos EX520 v1; cada uno conserva su propia calibración.

---

## 3. Limitaciones y advertencia

> **Esto es un firmware base de router, no un servidor doméstico.**
> Reproduce la funcionalidad de fábrica: enrutamiento, Wi-Fi, LAN/WAN, LED,
> botones, LuCI y repetidor.
>
> **No instale servidores/clientes VPN, AdGuard, Samba, Docker, clientes de
> torrents, servidores multimedia ni otros servicios pesados.**
> El router tiene **256 MB de RAM** y solo unos **21 MB** de overlay útil.
> Esos paquetes provocan fácilmente OOM, reinicios espontáneos, fallos de Wi-Fi
> y llenado de la flash.

### 3.1. Límites de hardware

- RAM: 256 MB.
- Flash: 128 MB SPI NAND, ~21 MB de overlay útil.
- Wi-Fi: MT7976CN DBDC (2.4 + 5 GHz).
- WAN: EN8801S; enlace verificado a 1G, 2.5G depende del peer y del controlador.
- No hay `factory.bin` oficial: la primera instalación requiere initramfs por
  TFTP + `sysupgrade`; la interfaz web de TP-Link no acepta OpenWrt.

### 3.2. No soportado

- TP-Link Cloud, EasyMesh, app móvil de TP-Link.
- Imágenes "todo en uno" con VPN/AdGuard/Samba/Docker.
- Instalación desde la interfaz web de TP-Link.
- EX520v y otras revisiones.

### 3.3. Cómo detectar que módulos extra van a desestabilizar el sistema

Compruebe el estado **antes** de instalar un paquete, **justo después** y
**tras reiniciar**. Si algún valor empeora, elimine el último paquete.

#### Comprobación rápida

```sh
free -m
cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|Slab|SReclaimable|SUnreclaim'
df -h /overlay
uptime
cat /proc/loadavg
nproc
```

#### Señales de peligro

| Métrica | Sano | Alarma |
|---|---|---|
| `MemAvailable` | > 50 MB | < 30 MB — riesgo de OOM |
| `SUnreclaim` | estable | crece durante horas — fuga en kernel/controlador |
| `load average` | por debajo de los núcleos | > 2 sostenido con 2 núcleos |
| `/overlay` | < 70% | > 80% — flash casi llena |
| OOM en logs | no | sí — el sistema ya es inestable |

#### Logs

```sh
dmesg | grep -iE 'oom|out of memory|killed process|mt76.*(error|fail|stuck)'
logread | grep -iE 'oom|out of memory|killed process|mt76.*(error|fail)'
```

#### Quién consume memoria

```sh
top -b -n1 | head -20
ps w
```

En LuCI: **Status → Overview**, **Status → Realtime Graphs**,
**Status → Processes**.

#### Cómo encontrar al culpable

1. Anote `MemAvailable`, `SUnreclaim`, `load average`, `df -h /overlay`.
2. Instale **un** paquete y reinicie.
3. Vuelva a medir.
4. Si `MemAvailable` bajó notablemente, `SUnreclaim` creció o apareció OOM,
   elimine el paquete:

```sh
apk del <nombre-del-paquete>
# compilaciones antiguas: opkg remove <nombre-del-paquete>
```

5. Desactive servicios innecesarios:

```sh
/etc/init.d/<service> stop
/etc/init.d/<service> disable
```

6. Si el Wi-Fi empieza a fallar bajo carga, revise primero la memoria y
   `dmesg` por errores de `mt76`/`ieee80211`, no solo el canal.

---

## 4. Instalación

### 4.1. Archivos

En la carpeta `bin/`:

```
openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
INSTALL.md
SHA256SUMS
recovery/ubi0.bin          (opcional, para recuperación)
```

Hashes de esta versión:

```
initramfs:  4a3ac2c99aea27de4b88d9f8b4cda4887f2ab7c90ee78adde52d78bb5368a3de
sysupgrade: 4b4652977f720be3ade6f18b493e39f89de33e83e6cad3e51dbbf9e589830b0a
ubi0:       a89574da99e4d00a19c1c7127db082986d45bf73e1115f2119b9ff6cb190083d
```

Verificación (macOS/Linux):

```bash
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin
shasum -a 256 openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

Windows (PowerShell):

```powershell
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin -Algorithm SHA256
Get-FileHash .\openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin -Algorithm SHA256
```

El segundo archivo es un contenedor tar (`kernel` + `root` + `CONTROL`) con
metadata. `sysupgrade` lo acepta sin `-F`; LuCI también.

### 4.2. Requisitos

- Router EX520 v1 y alimentación.
- UART de 3.3 V, 115200 8N1 (GND/TX/RX, no conectar VCC).
- Cable Ethernet: puerto LAN del router ↔ adaptador de red del PC.
- Servidor TFTP en el PC para el initramfs.
- Servidor HTTP en el PC para `-final.bin`.
- PC en `192.168.1.2/24`; el router es `192.168.1.1` en U-Boot.

---

### 4.3. Instalación en Windows

#### Paso 1. TFTP

1. Descargue y ejecute **Tftpd64** (o Tftpd32).
2. Abra la pestaña **TFTP**.
3. `Current Directory` — la carpeta con `ex520.itb`.
4. `Server Interface` — el adaptador con `192.168.1.2`.
5. Pulse **Start**.

#### Paso 2. Red y UART

1. Conecte el cable al **puerto LAN** del router.
2. Configure el adaptador de Windows en `192.168.1.2`, máscara `255.255.255.0`.
3. Abra PuTTY/Tera Term: puerto COM USB-UART, `115200`, 8N1, sin flow control.

#### Paso 3. Arrancar el initramfs

Encienda el router y detenga U-Boot (`Enter`/`Ctrl-C`; si aparece un menú,
elija `0. U-Boot console`).

En UART:

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Espere `root@OpenWrt:~#`.

#### Paso 4. Servidor HTTP

En una consola de Windows, entre en la carpeta con `-final.bin`:

```powershell
cd C:\ruta\a\bin
py -m http.server 8000
```

Si no tiene Python, instálelo desde python.org o use cualquier servidor HTTP
simple con raíz en esa carpeta.

Compruebe en el navegador: `http://192.168.1.2:8000/` — debe aparecer la lista
de archivos.

#### Paso 5. Instalar

En UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

El router descarga la imagen, valida la metadata, escribe los volúmenes UBI y
reinicia.

**No corte la alimentación.**

---

### 4.4. Instalación en macOS

#### Paso 1. TFTP

```bash
cd /ruta/a/bin
sudo cp openwrt-mediatek-filogic-tplink_ex520-v1-initramfs-kernel.bin /private/tftpboot/ex520.itb
sudo chmod 644 /private/tftpboot/ex520.itb
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
```

Si `launchctl` da error, el servicio suele estar ya activo. Verifique:

```bash
cd /tmp
tftp 127.0.0.1
```

En `tftp>`:

```text
binary
get ex520.itb
quit
```

#### Paso 2. Red y UART

```bash
networksetup -listallhardwareports
sudo ifconfig enX 192.168.1.2 netmask 255.255.255.0 up
ls /dev/cu.*
screen /dev/cu.usbserial-XXXX 115200
```

Salir de `screen`: `Ctrl-A`, luego `K`, luego `y`.

#### Paso 3. Arrancar el initramfs

Encienda el router y detenga U-Boot.

```text
tftpboot 0x46000000 ex520.itb
bootm 0x46000000
```

Espere `root@OpenWrt:~#`.

#### Paso 4. Servidor HTTP

En una segunda ventana de Terminal:

```bash
cd /ruta/a/bin
python3 -m http.server 8000
```

Compruebe: `http://192.168.1.2:8000/`.

#### Paso 5. Instalar

En UART:

```sh
sysupgrade -n http://192.168.1.2:8000/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

**No corte la alimentación.**

---

### 4.5. Después de la instalación

```sh
ip a
mount | grep overlay
df -h
dmesg | grep mt7981-eeprom
```

Esperado:
- LAN `192.168.1.1`;
- overlay desde `rootfs_data`;
- `mt7981-eeprom: EEPROM extracted from /tmp/misc_ro/0x003A0000`;
- LuCI: `http://192.168.1.1`.

### 4.6. Actualizaciones

LuCI → **System → Backup / Flash Firmware → Flash image**,
subir el mismo `-final.bin`.

O por SSH:

```sh
sysupgrade -n /tmp/openwrt-mediatek-filogic-tplink_ex520-v1-sysupgrade-final.bin
```

### 4.7. Recuperación

Si la instalación falla:

1. Arranque el initramfs por TFTP (sección 4.3/4.4).
2. Copie `recovery/ubi0.bin` a la carpeta del servidor TFTP.
3. En U-Boot:

```text
tftpboot 0x46000000 ubi0.bin
nmbm0 write 0x46000000 0xF00000 0x2800000
```

4. Apague y encienda el router.

`misc_ro` (calibración), `boot` y `u-boot-env` no se modifican.

---

## 5. Repetidor Wi-Fi

`relayd` y `luci-proto-relay` están instalados. Dos opciones:

- **Repetidor NAT** — más simple: el upstream se conecta como cliente, la red
  local sigue en `192.168.1.x`, doble NAT.
- **relayd** — una sola subred con el upstream: los clientes reciben direcciones
  del router upstream. Hay que desactivar DHCP en LAN y dar al repetidor una
  dirección libre de la subred upstream.

Los pasos detallados están en `bin/INSTALL.md` y en LuCI → Network.
Si el upstream también es `192.168.1.x`, cambie primero la LAN a `192.168.2.1`.

---

## 6. Compilar desde el código fuente

El código está en `src/`:

- `src/patches/openwrt-ex520-v1.patch` — parche para OpenWrt `bb8054e`;
- `src/files/` — archivos overlay;
- `src/build/build.sh` — compilación con Docker;
- `src/README.md` — detalles.

Compilación rápida:

```bash
cd src/build
./build.sh
```

El script clona OpenWrt, aplica el parche, instala los feeds, compila y crea
`-final.bin` con metadata.

---

## 7. Licencia

Ver `src/LICENSE`. OpenWrt es GPL-2.0; el EEPROM genérico es BSD-3-Clause-Clear.
