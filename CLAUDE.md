# Pinnacle-OS — Yocto embedded Linux for NXP i.MX 8M/9

## Overview

Pinnacle-OS is the Yocto/OpenEmbedded build system for the **Pinnacle**
platform — the **NXP i.MX 8M/9** Linux application core + on/off-chip Cortex-M
(i.MX RT class) real-time co-processor, communicating via RPMsg/OpenAMP.
Default board: **FRDM-i.MX 93** (machine `imx93-11x11-lpddr4x-frdm`). Built
with [kas](https://kas.readthedocs.io/) + Docker against the NXP `scarthgap`/
`walnascar` layer set (`fsl-imx-headless` distro), with A/B OTA updates via
[swupdate](https://sbabic.github.io/swupdate/).

## Quick Start

```bash
make kas-image              # Build the KAS Docker image (once)
make image frdm-imx93       # Build the Yocto image for i.MX 93
```

## Build Targets

```
make image  frdm-imx93       Build Yocto SD card image
make build  frdm-imx93       Alias for image
make rebuild-image frdm-imx93   cleansstate image recipe, then rebuild
make sdk    frdm-imx93       Cross-toolchain SDK installer → deploy/sdk/
make esdk   frdm-imx93       Extensible SDK installer     → deploy/esdk/
make shell  frdm-imx93       Interactive kas shell
make swu                      Build .swu OTA package
make flash  frdm-imx93 DEVICE=/dev/sdX   Flash image to SD card
```

## Boot Flow (i.MX 93)

```
SD/eMMC → Boot ROM → imx-boot (ATF + U-Boot) → U-Boot → Linux
        → systemd → Pinnacle-HAL (A-core) ↔ Cortex-M (M-core, RPMsg/OpenAMP)
```

## A/B OTA Layout

Partition table (`meta/meta-pinnacle/wic/sdimage-imx93.wks`):
```
  boot       FAT32   imx-boot, Image, DTB, extlinux
  rootfs-a   ext4    slot A (active after initial flash)
  rootfs-b   ext4    slot B (updated by swupdate, then activated)
  data       ext4    /home — persistent, never touched by OTA
```

`make swu` builds an `.swu` package. Signing via
`scripts/generate-swu-keys.sh` (RSA-4096).

## Layer Structure

| Layer               | Source                             | Purpose                              |
|---------------------|------------------------------------|--------------------------------------|
| `poky`              | poky (scarthgap/walnascar)         | OE core                              |
| `meta-oe`           | meta-openembedded                  | Package set                          |
| `meta-arm`          | meta-arm                           | ARM BSP / ATF                        |
| `meta-freescale`    | meta-freescale                     | NXP BSP base                         |
| `meta-freescale-distro` | meta-freescale-distro          | NXP distro policy (`fsl-imx-headless`)|
| `meta-imx`          | meta-imx                           | i.MX BSP, kernel, U-Boot, firmware   |
| `meta-swupdate`     | sbabic/meta-swupdate               | swupdate OTA framework               |
| `meta-pinnacle`     | SiliconCentric/meta-pinnacle (local, in `meta/`) | Pinnacle image, HAL, swu config |

## Repo Notes

- `build/`, `downloads/`, `sstate-cache/`, `layers/` are gitignored
  bind-mounted host dirs.
- `meta/meta-pinnacle` is committed **locally** in this repo (see
  `.gitignore`); upstream layers are cloned by kas into `layers/` and must
  never be hand-edited.
- `config` holds the Pinnacle-HAL repository URL.
