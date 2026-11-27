# Pinnacle-OS

**Remote:** `git@github.com:SiliconCentric/Pinnacle-OS.git`
**Parent project:** [Pinnacle](../Pinnacle.md) (target hardware: **NXP i.MX 8M/9** Linux app core + on/off-chip Cortex-M real-time co-processor via RPMsg/OpenAMP.)
**Leaf type:** `<Project>-OS`
**Status:** REAL — actively built out

Yocto-based embedded Linux OS for the **NXP i.MX 8M/9** platform. Built with
`kas` + Docker against the NXP layer set (`fsl-imx-headless` distro), with A/B
OTA updates via `swupdate`.

**Board:** default `frdm-imx93` (machine `imx93-11x11-lpddr4x-frdm`). Platform
customization lives in `meta/meta-pinnacle` (committed locally); upstream
layers (`poky`, `meta-openembedded`, `meta-arm`, `meta-freescale`,
`meta-freescale-distro`, `meta-imx`, `meta-swupdate`) are checked out by kas
into a **gitignored** `layers/` directory and must never be hand-edited.

**Targets:** `make build`, `make image`, `make shell [board]`, `make swu`,
`make sdk`/`esdk`, `make flash`, `make deploy-*`, `make clean`/`clean-all`.

**Boot flow (i.MX 93):**
```
SD/eMMC → Boot ROM → imx-boot (ATF + U-Boot) → U-Boot → Linux
        → systemd → Pinnacle-HAL (A-core) ↔ Cortex-M (M-core, RPMsg/OpenAMP)
```

**A/B OTA layout:** `boot` (FAT32), `rootfs-a`, `rootfs-b` (ext4, switched by
swupdate), `data` (`/home`, persistent).

**Local layer:** `meta/meta-pinnacle` is committed in-repo (see `.gitignore`),
matching the Acadia/Arches/Zion/Joshua convention.

**Architectural note:** Pinnacle-HAL is split into an A-core (Linux-facing
probes) and an M-core (deterministic real-time/safety) domain bridged by an
RPMsg/OpenAMP contract layer. The OS image ships both domains' tooling.

---
Part of the `Pinnacle` project in the `project-managers` fleet. See
`docs/project-managers.md` for the full 9-project / 8-leaf hierarchy and shared
conventions.
