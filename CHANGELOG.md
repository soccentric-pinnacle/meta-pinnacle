# Pinnacle-OS Migration Changelog

Complete record of all renames, reference removals, and platform substitutions
performed when porting from Raspberry Pi (Acadia) to NXP i.MX 93 (Pinnacle).

---

## Deleted Files

| File | Reason |
|---|---|
| `kas/boards/rpi5.yaml` | RPi board — replaced by `frdm-imx93.yaml` |
| `kas/boards/rpi4-64.yaml` | RPi board |
| `kas/boards/rpi4.yaml` | RPi board |
| `kas/boards/rpi3-64.yaml` | RPi board |
| `kas/boards/rpi3.yaml` | RPi board |
| `kas/boards/rpi2.yaml` | RPi board |
| `kas/boards/rpi1.yaml` | RPi board |
| `kas/boards/rpi0.yaml` | RPi board |
| `kas/boards/rpi0-2w.yaml` | RPi board |
| `kas/boards/rpi0-2w-64.yaml` | RPi board |
| `kas/boards/rpi0-wifi.yaml` | RPi board |
| `kas/boards/rpi-armv7.yaml` | RPi board |
| `kas/boards/rpi-armv8.yaml` | RPi board |
| `kas/boards/cm1.yaml` | RPi Compute Module 1 |
| `kas/boards/cm3.yaml` | RPi Compute Module 3 |
| `kas/boards/cm4.yaml` | RPi Compute Module 4 |
| `kas/boards/cm5.yaml` | RPi Compute Module 5 |
| `kas/repos/meta-raspberrypi.yaml` | RPi BSP layer — replaced by `meta-imx.yaml` |
| `kas/repos/meta-acadia.yaml` | Acadia layer repo — replaced by `meta-pinnacle.yaml` |
| `rpi-make-completion.bash` | RPi-specific bash completion — replaced by `pinnacle-make-completion.bash` |

---

## Created Files

| File | Purpose |
|---|---|
| `kas/boards/frdm-imx93.yaml` | FRDM i.MX 93 board config (`imx93-11x11-lpddr4x-frdm`) |
| `kas/repos/meta-imx.yaml` | NXP i.MX BSP layers (`meta-imx-bsp`, `meta-imx-sdk`) |
| `kas/repos/meta-arm.yaml` | ARM TF-A / OP-TEE layer (required for i.MX 93 boot) |
| `kas/repos/meta-pinnacle.yaml` | Pinnacle application layer (was `meta-acadia.yaml`) |
| `pinnacle-make-completion.bash` | Bash tab-completion for Pinnacle Makefile targets |
| `CHANGELOG.md` | This file |

---

## Modified Files

### `kas/common.yaml`

| Field | Old (Acadia/RPi) | New (Pinnacle/i.MX 93) |
|---|---|---|
| `includes` | `meta-raspberrypi`, `meta-acadia` | `meta-arm`, `meta-imx`, `meta-pinnacle` |
| `distro` | `poky` | `fsl-imx-headless` |
| `target` | `acadia-image` | `pinnacle-image` |
| `ENABLE_UART` | `"1"` (RPi-specific) | removed |
| `GPU_MEM` | `"128"` (VideoCore-specific) | removed |
| `LICENSE_FLAGS_ACCEPTED` | `synaptics-killswitch` (RPi firmware) | removed |
| `RPI_USE_U_BOOT` | `"1"` | removed |
| `UBOOT_MACHINE` | `rpi_arm64_defconfig` | removed (set by meta-imx machine conf) |
| `ACCEPT_FSL_EULA` | — | `"1"` (required for NXP proprietary firmware) |

### `kas/repos/poky.yaml`

| Field | Old | New |
|---|---|---|
| `branch` | `scarthgap` (Yocto 5.0 LTS) | `whinlatter` (Yocto 5.2, NXP BSP baseline) |

### `kas/repos/meta-openembedded.yaml`

| Field | Old | New |
|---|---|---|
| `branch` | `scarthgap` | `whinlatter` |
| `commit` | `HEAD` | `a4e768dcfae181dd99e39c4286fa0729ca7f4e47` (pinned to NXP 6.18.2-1.0.0 manifest) |

### `kas/repos/meta-swupdate.yaml`

| Field | Old | New |
|---|---|---|
| `branch` | `scarthgap` | `whinlatter` |

### `Makefile`

| Symbol | Old | New |
|---|---|---|
| Header comment | `RPi Yocto Build System` | `NXP i.MX 93 Yocto Build System` |
| `KAS_IMAGE` | `rpi5-kas:latest` | `imx93frdm-kas:latest` |
| `SDK_IMAGE` | `rpi5-sdk:latest` | `imx93frdm-sdk:latest` |
| `ESDK_IMAGE` | `rpi5-esdk:latest` | `imx93frdm-esdk:latest` |
| `IMAGE_TARGET` | `acadia-image` | `pinnacle-image` |
| `BOARD` default | `rpi5` | `frdm-imx93` |
| Board list comment | 17 RPi/CM variants | `frdm-imx93` |
| Kernel file (`swu`) | `kernel_2712.img` (RPi 5 firmware blob) | `Image` (ARM64 standard) |
| DTB file (`swu`) | `bcm2712-rpi-5-b.dtb` | `$(MACHINE).dtb` |
| Rootfs pattern (`swu`) | `acadia-image-$(MACHINE)*.rootfs.ext4` | `pinnacle-image-$(MACHINE)*.rootfs.ext4` |
| `sw-description` path | `meta/meta-acadia/swupdate/` | `meta/meta-pinnacle/swupdate/` |
| `pre-install.sh` path | `meta/meta-acadia/swupdate/` | `meta/meta-pinnacle/swupdate/` |
| `post-install.sh` path | `meta/meta-acadia/swupdate/` | `meta/meta-pinnacle/swupdate/` |
| Signing key path | `meta/meta-acadia/swupdate/keys/` | `meta/meta-pinnacle/swupdate/keys/` |
| `cpio` manifest | `kernel_2712.img`, `bcm2712-rpi-5-b.dtb` | `Image`, `$(MACHINE).dtb` |
| Completion script | `rpi-make-completion.bash` | `pinnacle-make-completion.bash` |

### `docker/yocto/Makefile`

| Symbol | Old | New |
|---|---|---|
| `IMAGE_NAME` | `rpi5-kas` | `imx93frdm-kas` |

### `docker/sdk/Makefile`

| Symbol | Old | New |
|---|---|---|
| `IMAGE_NAME` | `rpi5-sdk` | `imx93frdm-sdk` |

### `docker/esdk/Makefile`

| Symbol | Old | New |
|---|---|---|
| `IMAGE_NAME` | `rpi5-esdk` | `imx93frdm-esdk` |

### `config`

| Old | New |
|---|---|
| `git@github.com:SiliconCentric/Acaida-HAL.git` | `git@github.com:SiliconCentric/Pinnacle-HAL.git` |

### `patch_health.py`

| Old | New |
|---|---|
| `/home/sandesh/work/Acadia/Acadia-Server/...` | `/home/sandesh/work/Pinnacle/Pinnacle-Server/...` |

### `audit-report.md`

Renamed from "Acadia-OS Audit Report" to "Pinnacle-OS Audit Report". All
RPi-specific references (machine names, file paths, recipe names, user names,
boot-flow terminology) updated to i.MX 93 / Pinnacle equivalents.

---

## Platform Mapping Summary

| Acadia / Raspberry Pi | Pinnacle / NXP i.MX 93 |
|---|---|
| RPi 5 (`raspberrypi5`) | FRDM i.MX 93 (`imx93-11x11-lpddr4x-frdm`) |
| BCM2712 SoC | NXP i.MX 93 SoC |
| Cortex-A76 (single-domain) | Cortex-A55 + Cortex-M33 (heterogeneous) |
| VideoCore VII GPU | Ethos-U65 NPU |
| RPi firmware bootloader | ele-imx (EdgeLock Secure Enclave) |
| `config.txt` / `cmdline.txt` | U-Boot environment / `boot.scr` |
| `rpi_arm64_defconfig` | `imx93_11x11_evk_defconfig` (via meta-imx machine conf) |
| `kernel_2712.img` | `Image` |
| `bcm2712-rpi-5-b.dtb` | `imx93-11x11-lpddr4x-frdm.dtb` |
| `sdimage-rpi5.wks` | `sdimage-imx93.wks` |
| `meta-raspberrypi` | `meta-imx-bsp` + `meta-imx-sdk` |
| `meta-acadia` | `meta-pinnacle` |
| `acadia-image` | `pinnacle-image` |
| `acadia-hal` | `pinnacle-hal` |
| `acadia-client` | `pinnacle-client` |
| `poky` distro | `fsl-imx-headless` distro |
| Yocto `scarthgap` (5.0 LTS) | Yocto `whinlatter` (5.2) |
| `synaptics-killswitch` EULA | `ACCEPT_FSL_EULA = "1"` |
| PL011 / mini-UART | LPUART (`lpuart1`–`lpuart8`) |
| `i2c-bcm2835` | LPI2C (`lpi2c1`–`lpi2c8`) |
| `spi-bcm2835` | LPSPI (`lpspi1`–`lpspi8`) |
| — | FlexCAN (`flexcan1`, `flexcan2`) |
| GENET Ethernet | ENET-QOS / ENET1 |
| `pinctrl-bcm2835` GPIO | `imx93-pinctrl` GPIO |
| — | EdgeLock Secure Enclave (ele-imx) |
| — | OP-TEE (BL32) |

---

## [Unreleased] — Feature-complete OS layer

### Added
- **Complete Yocto layer** committed locally in `meta/meta-pinnacle`:
  - `recipes-core/images/pinnacle-image.bb` + `pinnacle-image-common.inc` +
    20 per-domain image variants
  - `recipes-core/pinnacle-data-init` — first-boot persistent `/home` init
  - `recipes-core/pinnacle-services` — dmesg capture + disk-usage monitoring
  - `recipes-core/systemd` — persistent journal + NTP timesyncd config
  - `recipes-core/os-release` — identifies image as "Pinnacle OS"
  - `recipes-core/packagegroup-pinnacle-middleware` / `-cloud`
  - `recipes-connectivity/pinnacle-connectivity` — Ethernet/WiFi/Bluetooth
  - `recipes-connectivity/pinnacle-timesync`
  - `recipes-bsp/pinnacle-hal` — HAL recipe (CMake + gRPC)
  - `recipes-support/expand-rootfs` — grow root to fill SD card
  - `recipes-support/swupdate` — RSA signing config fragment
  - `recipes-swupdate/pinnacle-swupdate-config` — A/B OTA runtime
  - `wic/sdimage-imx93.wks` — A/B OTA partition layout
  - `swupdate/sw-description` + `pre-install.sh` + `post-install.sh`
- **`scripts/generate-swu-keys.sh`** — RSA-4096 keypair generator
- **`CLAUDE.md`** and **`REPO_MAP.md`** — project documentation

### Fixed
- `.gitignore` now tracks `meta/meta-pinnacle/` locally while ignoring upstream
  `layers/`.

### Notes
- Pinnacle-OS is a direct port of the Acadia/Zion reference template,
  retargeted for NXP i.MX 8M/9 (`fsl-imx-headless` distro, machine
  `imx93-11x11-lpddr4x-frdm`). Boot chain, A/B OTA, and service layout
  preserved; kernel image (`Image`), DTB (`imx93-11x11-lpddr4x-frdm.dtb`), and
  U-Boot env flow adapted. Pinnacle-HAL's A-core/M-core (RPMsg/OpenAMP) split
  is preserved.
