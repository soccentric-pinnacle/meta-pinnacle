# Pinnacle-OS Audit Report

## Executive Summary

- Total requirements audited: 65
- PASS: 9
- PARTIAL: 20
- FAIL: 30
- N/A: 6
- Critical findings (must fix before production): 4
- Important findings (should fix soon): 8
- Minor findings (nice to have): 12

---

## Critical Findings

### C1 — No automatic rollback on boot failure [R3.1–R3.5]

**What's wrong:** The FRDM i.MX 93 uses the SoC firmware bootloader, not U-Boot. No bootcount, bootlimit, or automatic slot-fallback mechanism exists anywhere in the repo. `swupdate-bootcheck.sh` (the closest thing) explicitly says in its own comment: *"In a full rollback implementation an initramfs-based boot counter would decrement on each boot attempt and restore the old boot.scr/extlinux.conf when it reaches zero. This script represents the 'boot confirmed' step that would reset that counter."* — i.e., the counter is not implemented.

**Field consequence:** A bad update is pushed. `post-install.sh` rewrites `boot.scr/extlinux.conf` to the new slot and reboots. The new slot kernel panics or `systemd` hangs. The bootloader reads `boot.scr/extlinux.conf`, boots the bad slot again. Forever. A human must drive to the lab with an SD card reader or serial cable.

**File:** `meta/meta-pinnacle/recipes-swupdate/imx93-swupdate-config/files/swupdate-bootcheck.sh` — entire file  
`meta/meta-pinnacle/swupdate/post-install.sh` — no `tries_remaining` or equivalent tracking

**Recommended fix:** Implement a FAT-filesystem boot counter on p1. Options:
- Write `tries_remaining=3` to `/boot/pinnacle-boot-state` in `post-install.sh`. Create a `BOOT_WATCHDOG` initramfs hook (via `meta-pinnacle/recipes-core/initramfs-*`) that decrements the counter on every boot attempt and restores the previous `boot.scr/extlinux.conf` root= entry when it hits zero. On confirmed-good boot, `swupdate-bootcheck.service` resets the counter to 3.
- Alternative: Use `U-Boot bootcount` — the NXP i.MX firmware's built-in single-boot mechanism (`reboot "0 U-Boot bootcount"` + `boot.scr`) which is native to NXP i.MX firmware ≥ 2023. This requires no initramfs and is simpler. See i.MX 93 docs for `U-Boot bootcount`.

**Estimated effort:** 3–5 days (U-Boot bootcount path is faster; initramfs path is more general).

---

### C2 — No swupdate image signing [R2.7]

**What's wrong:** `swupdate.cfg` has no `signingalg` or `swupdate-public-key` stanza. `make swu` in the Makefile does not sign the cpio archive. The Mongoose web server accepts unsigned `.swu` packages over plain HTTP on port 8080. Any host on the lab network can push a malicious rootfs to any device without credentials.

**Files:**  
`meta/meta-pinnacle/recipes-swupdate/imx93-swupdate-config/files/swupdate.cfg` — no signing section  
`Makefile` lines 255–271 (`swu:` target) — no `openssl dgst` or `swupdate-sign` call  
`meta/meta-pinnacle/swupdate/sw-description` — no `signed` attribute

**Recommended fix:**
1. Generate an RSA-4096 keypair. Store the private key outside the repo (CI secrets, USB key, or a GPG-encrypted file explicitly `.gitignore`d). Commit only the public key under `meta/meta-pinnacle/swupdate/keys/public.pem`.
2. Add to `swupdate.cfg`:
   ```
   globals: { signingalg = "RSA-PKCS1-v1_5"; }
   ```
3. In `swupdate_%.bbappend`, add:
   ```
   SWUPDATE_SIGNING = "RSA"
   SWUPDATE_PRIVATE_KEY = "${LAYERDIR}/../swupdate/keys/public.pem"
   ```
   (public key for verification on device)
4. In `make swu`, after cpio-packing, sign `sw-description` and embed the signature per the [swupdate signing docs](https://sbabic.github.io/swupdate/signed_images.html).

**Estimated effort:** 1–2 days.

---

### C3 — Pinnacle-Client not in the image [R4.2, R5.1, R5.2]

**What's wrong:** There is no `pinnacle-client` recipe anywhere in `meta/meta-pinnacle/`. `core-image-full-cmdline.bbappend` has no `IMAGE_INSTALL:append = " pinnacle-client"`. No `pinnacle-client.service` unit exists. The OS is missing one of its two core userspace applications.

**Files:** Entire `meta/meta-pinnacle/recipes-*` tree — no client recipe found.

**Recommended fix:** Create `meta/meta-pinnacle/recipes-connectivity/pinnacle-client/pinnacle-client_git.bb` mirroring `pinnacle-hal_git.bb`. Pin `SRCREV` to a specific commit hash. Add a `pinnacle-client.service` unit with:
```
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
User=pinnacle
WorkingDirectory=/var/lib/pinnacle
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=5
```
Add `IMAGE_INSTALL:append = " pinnacle-client"` to the bbappend.

**Estimated effort:** 1–2 days.

---

### C4 — Default password committed to the repo [R12.1, R12.3]

**What's wrong:** `core-image-full-cmdline.bbappend` line 106 sets a password hash for user `pinnacle`. The comment on line 104 says `password 'pinnacle'`. User `pinnacle` is in group `sudo`. Any lab board running this image is accessible via `ssh pinnacle@<ip>` with password `pinnacle`, gaining full root via `sudo`. This is a committed default credential in a publicly fetchable layer.

**File:** `meta/meta-pinnacle/recipes-core/images/core-image-full-cmdline.bbappend` lines 103–107

**Recommended fix:**
1. Remove `usermod -p ...` from `EXTRA_USERS_PARAMS`. Lock the password: `usermod -L pinnacle` or set it to `!`.
2. Provision SSH public keys for the `pinnacle` user at image build time via `authorized_keys` in a non-public file (CI secret or separate secrets layer), or document that the first-boot setup script must inject a key.
3. Disable password authentication in sshd: create `meta/meta-pinnacle/recipes-connectivity/openssh/openssh_%.bbappend` that installs a `sshd_config` with `PasswordAuthentication no`.

**Estimated effort:** 2–4 hours.

---

## Important Findings

### I1 — `SRCREV = "${AUTOREV}"` on pinnacle-hal and HEAD on most layers [R5.3, R10.3]

`pinnacle-hal_git.bb` line 7: `SRCREV = "${AUTOREV}"`. `kas/repos/poky.yaml`, `kas/repos/meta-openembedded.yaml`, `kas/repos/meta-swupdate.yaml`, and `kas/repos/meta-pinnacle.yaml`, `kas/repos/meta-arm.yaml` all set `commit: HEAD`. Only `meta-imx.yaml` and `meta-arm.yaml` are pinned.

Two consecutive `make image` invocations will produce different rootfs binaries. This breaks sstate cache coherence for the team and makes debugging field issues impossible ("which build is on this board?"). `AUTOREV` also randomly re-fetches on any BitBake run.

**Fix:** Pin every repo to a specific commit SHA. For `pinnacle-hal_git.bb` replace `AUTOREV` with the HEAD SHA of the target branch. Pin poky, meta-openembedded, meta-swupdate, and meta-pinnacle in their respective repo yamls. Set `SOURCE_DATE_EPOCH` in `local_conf_header` in `kas/common.yaml`.

---

### I2 — No automatic boot fallback means the SWUpdate web UI is the only recovery path [R3.4]

Extends C1. If an update is pushed and the new slot crashes before `swupdate-bootcheck.service` runs, the only recovery options are: (a) SSH into the device before the reboot completes — impractical, (b) serial console + manual `boot.scr/extlinux.conf` edit. There is no documented SOP for this. For boards in a lab running long tests this is a 1-person-trip-to-the-lab event.

**Fix:** Implement the U-Boot bootcount or initramfs-counter mechanism from C1. Until then, add an explicit recovery runbook to `meta/meta-pinnacle/swupdate/README.md` under a "Recovery: bad OTA" section, and enforce serial console access on all boards.

---

### I3 — Kernel and DTBs not in the OTA payload [R2.6]

`meta/meta-pinnacle/swupdate/sw-description` updates only `rootfs.ext4.gz` via the raw handler. The kernel (`Image`, `Image`) and device tree blobs live on p1 (FAT32, `/boot`) and are NOT updated by swupdate. If a new kernel or overlay is required for a new HAL/Client version, a manual `/boot` update is needed.

**Fix:** Add `images:` blocks for kernel and DTB files using the `rawfile` handler targeting `/boot/Image`, `/boot/imx93-11x11-lpddr4x-frdm.dtb`, and any required overlays. Update `pre-install.sh` and `post-install.sh` to `remount /boot rw` before handler runs and `ro` after. Add versioned A/B copies of the DTB to avoid bricking if DTB write is interrupted (or accept the risk since `/boot` is FAT32 and small writes are fast).

---

### I4 — `swupdate-bootcheck.service` does not confirm application health or mark slot [R4.3, R4.4]

`swupdate-bootcheck.sh` logs the active slot and writes `/run/swupdate-active-slot`. It does not: verify `pinnacle-hal` loads, verify `pinnacle-client` connects to the server, or call any slot-confirmation command. It runs at `sysinit.target` (very early), not after the application stack. If the applications fail to start after a good kernel boot, the board is still considered "confirmed" and no rollback is triggered.

**File:** `meta/meta-pinnacle/recipes-swupdate/imx93-swupdate-config/files/swupdate-bootcheck.service` line 6: `After=local-fs.target` — should be `After=pinnacle-client.service` (and include a timeout)

**Fix:** Rename/extend the service. Add `After=pinnacle-client.service` and `TimeoutSec=120`. Have the script probe actual application health (e.g., gRPC health-check endpoint ping) before writing the confirmation. On failure, trigger slot rollback (via U-Boot bootcount or boot.scr/extlinux.conf restore).

---

### I5 — No persistent journald storage [R4.5, R11.1]

No `journald.conf` is installed anywhere in the layer. Default systemd in a poky image uses `Storage=auto`, which falls back to volatile (`/run/log/journal`) when `/var/log/journal` does not exist. On a minimal image, `/var/log/journal` is typically absent. Logs are lost on every reboot.

For unattended boards that reboot after a bad update, there are zero logs to diagnose why it failed.

**Fix:** Create a recipe or bbappend (e.g., `recipes-core/systemd/systemd_%.bbappend`) that installs `/etc/systemd/journald.conf.d/pinnacle.conf` with:
```
[Journal]
Storage=persistent
SystemMaxUse=512M
SystemKeepFree=100M
```
Ensure `/var/log/journal` exists in the image (add `mkdir -p /var/log/journal` to `do_install` or use `ROOTFS_POSTPROCESS_COMMAND`).

---

### I6 — No persistent data partition for Pinnacle-Client spool [R7.1, R7.3, R7.4]

The `.wks` file mounts p4 at `/home`, not at a dedicated app-data path. The `swupdate/README.md` describes p4 as `/data` — this disagrees with the actual `.wks` configuration. Neither `/var/lib/pinnacle` nor any similar path is defined or mounted. Pinnacle-Client has nowhere to persist its state across OTA updates.

**Files:**  
`meta/meta-pinnacle/wic/sdimage-imx93.wks` line 22: `part /home ... --label home`  
`meta/meta-pinnacle/swupdate/README.md` lines 64–65: describes p4 as `/data`

**Fix:** Either (a) add a fifth partition for app data and mount it at `/var/lib/pinnacle` with `ext4,errors=remount-ro` in `/etc/fstab`, or (b) repurpose p4 as `/data` (updating `.wks`, `fstab`, and `imx93-home-init`). Option (b) requires moving user home dirs to rootfs or another path. Whichever you choose, fix the documentation inconsistency. Add an `fstab` recipe that sets `errors=remount-ro,noatime` (but test whether Pinnacle-Client's database needs `atime`; if using SQLite WAL mode, `noatime` is fine).

---

### I7 — swupdate web UI unauthenticated on HTTP [R6.1, R12.4]

`swupdate-webui.conf` starts swupdate with `--port 8080` over plain HTTP. There is no authentication layer. Any host on the lab network can push an arbitrary `.swu` to any device without credentials (even before C2 signing is fixed). Combined with C4 (default SSH password), a lab network compromise gives full control of all boards.

**Fix:** Short-term: add `--auth-domain` and `--auth-user` options to the Mongoose launch in `swupdate-webui.conf` to require HTTP Basic Auth. Medium-term: sign all packages (C2) so unsigned pushes are rejected even if the UI is accessible.

---

### I8 — No CI configuration [R10.4, R10.5]

No `.github/`, `.gitlab-ci.yml`, `Jenkinsfile`, or equivalent CI configuration exists. Builds are never automatically validated on PR. No artifacts are automatically produced or versioned. The only build gate is a developer's local `make image`.

**Fix:** Add a GitHub Actions workflow (or equivalent) that runs `make image frdm-imx93` on PR using the Docker-in-Docker kas container. Cache `sstate-cache` and `downloads` between runs via GH cache actions. Export `.wic.bz2`, `.swu`, and a version manifest (`git describe --tags`) as build artifacts.

---

## Minor Findings

### M1 — No machine configs in meta-pinnacle [R1.4]

`meta/meta-pinnacle/conf/` has only `layer.conf`. Machine definitions are inherited from `meta-imx`. This is normal for an i.MX 93-only OS, but means `MACHINEOVERRIDES` cannot be used to gate pinnacle-specific features per board. If a future SoM is added that is not in `meta-imx`, this gap becomes a blocker.

**Fix:** Acceptable for now. Document in README that machine configs are delegated to meta-imx. If non-i.MX 93 boards are added, create `conf/machine/` in meta-pinnacle.

---

### M2 — No `local.conf.sample` [R1.6]

The build system uses kas to generate `build/conf/local.conf` from kas yamls. A developer who does not understand kas cannot easily replicate a build manually. The generated `build/conf/local.conf` is present in the repo (which is atypical — usually it's `.gitignore`d).

**Fix:** Either `.gitignore` `build/conf/local.conf` and add a kas quickstart to README, or provide a `local.conf.sample` in `meta/meta-pinnacle/conf/`. The kas documentation in README is adequate for developers who read it; a sample gives a fallback for those who don't.

---

### M3 — No dedicated `pinnacle-image.bb` [R1.5]

The image is `core-image-full-cmdline` customised via a `bbappend`. This works but `core-image-full-cmdline` includes a compiler toolchain, `man-pages`, `popt`, and other packages that are unnecessary on an embedded IV&V device.

**Fix:** Create `meta/meta-pinnacle/recipes-core/images/pinnacle-image.bb` inheriting from `core-image-base` (or `core-image-minimal`) and add precisely what is needed. This gives control over image size and eliminates accidental inclusion of upstream package additions.

---

### M4 — `pinnacle-hal_git.bb` fetches over SSH with `branch=master` [R5.3]

`SRC_URI` in `pinnacle-hal_git.bb` line 6: `protocol=ssh;user=git;branch=master`. SSH fetch requires the build host to have SSH keys configured for the GitHub org. Branch `master` is mutable. The repo URL also has a typo: `Pinnacle-HAL` (transposition) which matches the kas `meta-pinnacle.yaml` URL `meta-pinnacle.git` — consistent but looks like a typo in the actual GitHub repo name.

**Fix:** Use HTTPS with a deploy token (or git token) for CI compatibility. Pin `SRCREV` to a specific commit SHA.

---

### M5 — `protobuf-compiler` in the image [R5.5]

`core-image-full-cmdline.bbappend` line 30 adds `protobuf-compiler` to `IMAGE_INSTALL`. The Protocol Buffers compiler is a build tool, not a runtime dependency. It doubles protobuf image size and adds a code-generation attack surface.

**Fix:** Remove `protobuf-compiler` from `IMAGE_INSTALL`. It belongs in the SDK (`TOOLCHAIN_HOST_TASK`), not the device image.

---

### M6 — No `vim` or `nano` in `IMAGE_INSTALL` [R5.4]

The `IMAGE_INSTALL` list includes `picocom`, `minicom`, `ethtool`, `strace`, etc., but no text editor. Field debugging often requires editing files on-device.

**Fix:** Add `vim` or `nano` to `IMAGE_INSTALL:append`.

---

### M7 — `systemd-timesyncd` not explicitly configured [R4.7]

`systemd-timesyncd` is part of the systemd package and is likely enabled by default in poky's systemd init. However, there is no `timesyncd.conf` in meta-pinnacle with explicit NTP servers. gRPC TLS and timestamp-based test logs depend on accurate time. If the default NTP servers are firewalled in the lab environment, time sync silently fails.

**Fix:** Create `recipes-core/systemd/systemd-timesyncd_%.bbappend` or a `timesyncd.conf` snippet with the lab NTP server address (or a public pool fallback).

---

### M8 — No factory reset or force-fallback mechanism [R8.4]

There is no documented way to force a board to slot A without serial console access. No GPIO trigger, no file marker on the boot partition, and no `U-Boot bootcount` integration.

**Fix:** Implement as part of the U-Boot bootcount rollback work (C1). A `make force-slot-a DEVICE=<ip>` Makefile target that SSHes in and rewrites `boot.scr/extlinux.conf` to rootfs-a's PARTUUID would cover the interim case.

---

### M9 — `swupdate/README.md` documents p4 as `/data`, `.wks` mounts it as `/home` [R7.1]

Documentation inconsistency. `meta/meta-pinnacle/swupdate/README.md` line 64 says `p4 | data | ... | /data`. `meta/meta-pinnacle/wic/sdimage-imx93.wks` line 22 says `part /home ... --label home`.

**Fix:** Align the two. Whichever path is chosen (see I6), update all documentation to match.

---

### M10 — No disk usage monitoring [R7.5]

No recipe installs a cron job or systemd timer to alert on disk usage. On a board running long tests, log accumulation or application spool growth can silently fill the rootfs (8 GB) or the home partition.

**Fix:** Add a simple systemd timer + script that runs `df -h` and logs a warning to syslog when any partition exceeds 80% usage. Alternatively, configure journald's `SystemMaxUse` (I5 fix) which implicitly caps log growth.

---

### M11 — SSH password authentication not explicitly disabled [R8.3]

No `sshd_config` override is installed. The default poky `openssh` `sshd_config` allows password authentication. Combined with C4 (default `pinnacle` password), this is a compound issue. Even after C4 is fixed, future operators might set a simple password for convenience.

**Fix:** Install `/etc/ssh/sshd_config.d/pinnacle-hardening.conf` via a recipe with:
```
PasswordAuthentication no
PermitRootLogin no
```

---

### M12 — No dmesg capture to disk at boot [R11.2]

No oneshot unit saves `dmesg` output to `/var/log/dmesg.boot` at boot. Combined with I5 (volatile journal), kernel boot messages are lost on reboot, making post-mortem on boot failures difficult.

**Fix:** Add a `dmesg-capture.service`:
```
[Unit]
After=local-fs.target
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'dmesg > /var/log/dmesg.boot'
RemainAfterExit=yes
```

---

## Detailed Requirement Walkthrough

### R1. Yocto Foundation

**R1.1 PASS** — `meta/meta-pinnacle/conf/layer.conf`: `BBFILE_COLLECTIONS += "meta-pinnacle"`, `BBFILE_PRIORITY_meta-pinnacle = "10"`, `LAYERSERIES_COMPAT_meta-pinnacle = "scarthgap"`, `LAYERDEPENDS_meta-pinnacle = "core imx93"`. All required fields present.

**R1.2 PASS** — Layer named `meta-pinnacle`. Follows Yocto convention.

**R1.3 PARTIAL** — `README.md` documents the kas-based workflow and layer structure. The `bblayers.conf` generated by kas is in `build/conf/bblayers.conf` and lists all layers. However, no standalone `BBLAYERS.conf.sample` exists for developers who want to run without kas. Adequate for the kas-first workflow documented; inadequate for manual BitBake builds.

**R1.4 FAIL** — `meta/meta-pinnacle/conf/` contains only `layer.conf`. No `conf/machine/` directory exists. All machine definitions come from `meta-imx`. `MACHINEOVERRIDES` cannot be used to apply pinnacle-specific settings per board without extending upstream machine configs.

**R1.5 PARTIAL** — No `pinnacle-image.bb`. The image is `core-image-full-cmdline` customized via `meta/meta-pinnacle/recipes-core/images/core-image-full-cmdline.bbappend`. Produces a bootable image. The bbappend approach is common but inherits whatever `core-image-full-cmdline` includes, including a cross-compiler.

**R1.6 FAIL** — No `local.conf.sample` or `site.conf.sample` anywhere in the repo. The kas-generated `build/conf/local.conf` is present (committed) and usable, but a new developer who is unfamiliar with kas cannot easily construct an alternative.

---

### R2. swupdate Integration

**R2.1 PASS** — `meta/meta-pinnacle/recipes-core/images/core-image-full-cmdline.bbappend` lines 2–6: `IMAGE_INSTALL:append = " swupdate swupdate-www imx93-swupdate-config"`. `PACKAGECONFIG:append:pn-swupdate = " webserver"` in `kas/common.yaml` and `build/conf/local.conf`.

**R2.2 PARTIAL** — `swupdate.cfg` is installed to `/etc/swupdate/swupdate.cfg` via `imx93-swupdate-config.bb`. `sw-description` exists in `meta/meta-pinnacle/swupdate/sw-description` but is a host-side template, not installed to the device. The template has `@@VERSION@@` substituted by `make swu`. This is architecturally correct for swupdate, but the template's install path on the device is not documented — it lives only inside the `.swu` cpio archive at update time, not persistently on the target.

**R2.3 PASS** — `Makefile` `swu:` target (lines 255–271): finds latest `rootfs.ext4`, gzip-compresses, substitutes version in `sw-description`, copies scripts, cpio-packs into `build/<board>-<version>.swu`. Wired to run after `build`.

**R2.4 PARTIAL** — A/B dual-rootfs is implemented via slot identification (p2/p3 by `findmnt`) and `boot.scr/extlinux.conf` rewriting. However, slot selection is entirely at the OS layer (post-install.sh editing boot.scr/extlinux.conf), not at the bootloader level. The `swupdate.cfg` has no `hw-revision` selection or `bootenv` handler. There is no `upgrade_available` gate. Functionally A/B, but the bootloader knows nothing about the state machine.

**R2.5 PASS** — `meta/meta-pinnacle/wic/sdimage-imx93.wks`: p2 `rootfs-a` (8192 MB ext4) and p3 `rootfs-b` (8192 MB ext4) both defined.

**R2.6 PARTIAL** — `sw-description` has one `images:` block: `rootfs.ext4.gz` via `raw` handler. No kernel (`Image`) or DTB (`imx93-11x11-lpddr4x-frdm.dtb`) handler. Kernel and DTBs on the shared FAT32 `/boot` partition are not part of the OTA payload. Any update requiring a new kernel cannot be delivered safely via this mechanism.

**R2.7 FAIL** — `swupdate.cfg` has no signing configuration. `make swu` does not sign the package. `sw-description` has no `signed` attribute. Unsigned packages accepted by the running daemon. See Critical Finding C2.

---

### R3. Bootloader & A/B Mechanics

The FRDM i.MX 93 uses the Broadcom SoC firmware as its primary bootloader, not U-Boot. This makes R3.1–R3.5 architecturally challenging but not impossible (NXP i.MX firmware supports `U-Boot bootcount`). R3.6 and R3.7 are N/A.

**R3.1 FAIL** — No bootloader-level A/B slot selection variable. The firmware reads `boot.scr/extlinux.conf` `root=PARTUUID=...` which is rewritten by `post-install.sh`. No `BOOT_ORDER` env, no `boot.scr` U-Boot bootcount integration.

**R3.2 FAIL** — No boot counter. `swupdate-bootcheck.sh` comment: "In a full rollback implementation an initramfs-based boot counter... would decrement on each boot attempt." Not implemented.

**R3.3 FAIL** — No boot limit. Dependent on R3.2; since R3.2 is unimplemented, this is trivially FAIL.

**R3.4 FAIL** — No automatic fallback on repeated boot failure. See Critical Finding C1.

**R3.5 FAIL** — No `upgrade_available` equivalent. `post-install.sh` unconditionally rewrites `boot.scr/extlinux.conf` to the new slot. After reboot there is no flag that says "this is a freshly-updated boot, apply fallback rules."

**R3.6 N/A** — U-Boot not used. Redundant env storage not applicable.

**R3.7 N/A** — U-Boot not used. `fw_setenv`/`fw_printenv` not applicable. Note: if U-Boot bootcount is adopted for R3.1 fix, `fw_env.config` remains N/A but a `U-Boot bootcount-state.conf` equivalent on `/boot` should be documented.

---

### R4. systemd Service Configuration

**R4.1 PARTIAL** — `meta/meta-pinnacle/recipes-bsp/pinnacle-hal/pinnacle-hal_git.bb` builds the HAL library and CLI. No `pinnacle-hal.service` unit is in the recipe. If the HAL runs as a daemon, there is no unit. If it is a library only (no daemon), R4.1 is N/A — but this is unclear from the recipe alone.

**R4.2 FAIL** — No `pinnacle-client` recipe. No `pinnacle-client.service` unit. The daemon is absent from the image. See Critical Finding C3.

**R4.3 PARTIAL** — `swupdate-bootcheck.service` runs `swupdate-bootcheck.sh` which logs the active slot. It does NOT: verify HAL loads (`pinnacle-hal --selftest` or equivalent), verify Client connects to the server (gRPC health check), or call `swupdate -c` / set any slot confirmation state. It is a logging service, not a health check.

**R4.4 FAIL** — `swupdate-bootcheck.service` declares `After=local-fs.target` and `WantedBy=sysinit.target`. It runs before `network.target`, let alone `pinnacle-client.service`. The dependency ordering is wrong for a health check.

**R4.5 FAIL** — No `journald.conf` installed by any recipe in meta-pinnacle. No `Storage=persistent`. See Important Finding I5.

**R4.6 PASS** — `imx93-connectivity.bb` installs systemd-networkd configs for Ethernet (DHCP) and WLAN. `80-imx93-connectivity.preset` enables `systemd-networkd.service`, `systemd-resolved.service`, `wpa_supplicant@eth0.service`, and `bluetooth.service`. Ethernet auto-up is configured.

**R4.7 PARTIAL** — `systemd-timesyncd` is part of the systemd package and is enabled by the systemd INIT_MANAGER. However, no `timesyncd.conf` with explicit NTP servers is installed. The default configuration uses pool.ntp.org which may be blocked in lab environments. Not verified as actively configured.

---

### R5. Image Composition

**R5.1 PARTIAL** — HAL is baked in (`IMAGE_INSTALL:append = " pinnacle-hal"` in bbappend line 100). Client is not in the image (no recipe exists). See C3.

**R5.2 PARTIAL** — `meta/meta-pinnacle/recipes-bsp/pinnacle-hal/pinnacle-hal_git.bb` pulls HAL from GitHub via `SRC_URI`. No `pinnacle-client` recipe exists.

**R5.3 FAIL** — `pinnacle-hal_git.bb` line 7: `SRCREV = "${AUTOREV}"`. Tracks `branch=master`. `kas/repos/poky.yaml`: `commit: HEAD`. `kas/repos/meta-openembedded.yaml`: `commit: HEAD`. `kas/repos/meta-swupdate.yaml`: `commit: HEAD`. `kas/repos/meta-pinnacle.yaml`: `commit: HEAD`. Only `meta-imx` is pinned. Builds are not reproducible.

**R5.4 PARTIAL** — `strace`, `iotop`, `sysstat`, `ethtool`, `lshw`, `can-utils`, `i2c-tools`, `usbutils`, `pciutils` all present. `journalctl`/`dmesg` via systemd. `ss` via iproute2 (pulled in as a systemd dependency). No `vim` or `nano` in `IMAGE_INSTALL`.

**R5.5 PARTIAL** — `protobuf-compiler` is in `IMAGE_INSTALL` (line 30 of bbappend): this is a build tool, not a runtime dependency. `sudo` is installed. No explicit cross-compiler toolchain (`gcc`, `binutils`) added to the image, but `core-image-full-cmdline` base image pulls in some development tools.

**R5.6 PARTIAL** — Build artifacts not available for direct size measurement. The rootfs partition is 8 GB. With gRPC, protobuf, Python3, Bluetooth stack, and all listed tools, the actual populated rootfs will likely be 2–4 GB compressed — acceptable for the 8 GB allocation, but `protobuf-compiler` and other dev tools should be removed to keep it lean.

---

### R6. OTA Delivery Model

**R6.1 PASS** — Model is manual push: web UI drag-and-drop at `http://<ip>:8080` or `swupdate-client -v <ip> <file>.swu`. Documented in `meta/meta-pinnacle/swupdate/README.md` with step-by-step instructions. Build-side packaging via `make swu`.

**R6.2 N/A** — Suricatta/Hawkbit not configured.

**R6.3 N/A** — Pinnacle-Client-triggered OTA not configured (and Pinnacle-Client is absent from the image).

**R6.4 PARTIAL** — Delivery procedure is documented in `meta/meta-pinnacle/swupdate/README.md`. No formal recovery runbook for "update delivered but device unresponsive" scenario.

**R6.5 PARTIAL** — `@@VERSION@@` in `sw-description` is substituted by `make swu SWU_VERSION=x.y.z`. The version is readable post-update via `http://<ip>:8080/api/v1/versioning`. No version manifest file (e.g. `version.json`) is produced or exported by `make swu` for independent verification.

---

### R7. Persistent Data and Spool

**R7.1 FAIL** — `sdimage-imx93.wks` p4 is `--label home` mounted at `/home` (512 MB static + first-boot expansion). No persistent data partition at `/var/lib/pinnacle` or `/data`. The `swupdate/README.md` describes p4 as `/data` — this is a documentation inconsistency with the actual `.wks` file.

**R7.2 PARTIAL** — p4 (whatever it's mounted as) is not written by swupdate (only p2/p3 are targets). Data on p4 survives OTA. However, the partition is designed for `/home` user directories, not application state. Application spool for Pinnacle-Client has no defined location.

**R7.3 FAIL** — No `fstab` recipe or file in meta-pinnacle. The wks file defines the partition but does not specify runtime mount options. `errors=remount-ro`, `noatime`, `barrier=1` are not set anywhere.

**R7.4 FAIL** — No persistent data partition for Pinnacle-Client. No recipe creates `/var/lib/pinnacle` or sets ownership. Client does not exist in the image (C3).

**R7.5 FAIL** — No disk usage monitoring service, timer, or cron job in the layer.

---

### R8. Recovery and Failure Handling

**R8.1 PARTIAL** — `README.md` documents `make flash frdm-imx93 DEVICE=/dev/sdX` for initial flashing. `meta/meta-pinnacle/swupdate/README.md` has a "Manually switch slot (emergency)" section with the `boot.scr/extlinux.conf` sed command. No dedicated "board is bricked, here is the recovery procedure" runbook. No USB recovery or boot-from-alternate-media procedure documented.

**R8.2 PASS** — Serial console is enabled on the i.MX 93 via U-Boot `console=` in `boot.scr` / `extlinux.conf` and the `LPUART` driver in meta-imx defaults. Console is available during boot for recovery.

**R8.3 PARTIAL** — `openssh` is referenced implicitly (`imx93-home-init.service` line 6: `Before=sshd.service`), so SSH is present. Password authentication is not explicitly disabled. Default user `pinnacle` has a password set (C4). No `sshd_config` override recipe. Key-based auth is not enforced by configuration.

**R8.4 FAIL** — No factory reset mechanism. No GPIO trigger at boot, no file marker (e.g. `/boot/force-slot-a`), no documented procedure beyond manual `boot.scr/extlinux.conf` edit via serial.

---

### R9. Multi-Board / SoM Support

**R9.1 PARTIAL — 1 board yaml file in `kas/boards/` (`frdm-imx93.yaml`), setting the correct `machine: imx93-11x11-lpddr4x-frdm`. A/B OTA WKS override (`WKS_FILE = "sdimage-imx93.wks"`) is present. Single board target; A/B layout applies to all builds.

**R9.2 N/A** — HAL source code is out of scope for this audit. Device tree correctness relative to HAL expectations cannot be verified from the OS layer alone.

**R9.3 PARTIAL** — `meta/meta-pinnacle/recipes-kernel/linux/linux-imx93_6.6.bbappend` pins the kernel commit for `imx93-11x11-lpddr4x-frdm` only. No kernel config fragments (`.cfg` files) are added by meta-pinnacle to ensure specific drivers (I2C, SPI, GPIO, CAN) are compiled in. These may be included by default in the i.MX 93 kernel config, but this is not verified in the layer.

**R9.4 FAIL** — `README.md` covers the board table and build commands. There is no section or document explaining how to add a new board (create kas yaml, set MACHINE, add machine config or reuse meta-imx, add WKS override if A/B needed).

---

### R10. Build, CI, and Reproducibility

**R10.1 PASS** — `Makefile` with targets: `build`/`image`, `rebuild-image`, `sdk`, `esdk`, `sdk-image`, `esdk-image`, `shell`, `swu`, `flash`, `kas-image`. `README.md` Quick Start section covers the full flow.

**R10.2 PARTIAL** — Prerequisites table in `README.md`: Docker 20.10+, GNU Make 4.0+, curl, bmaptool. Yocto version: scarthgap (documented via `LAYERSERIES_COMPAT`). BSP versions: meta-imx commit pinned; poky, meta-oe, meta-swupdate, meta-pinnacle at HEAD (undocumented floating refs). Host tools required inside the Docker container are implicit.

**R10.3 FAIL** — `SOURCE_DATE_EPOCH` not set in `kas/common.yaml` or `local.conf`. Three of four external layers (`poky`, `meta-openembedded`, `meta-swupdate`) are at `HEAD`. `meta-pinnacle` is at `HEAD` with `SRCREV = "${AUTOREV}"` on pinnacle-hal. Builds are not reproducible.

**R10.4 FAIL** — No CI configuration found. No `.github/workflows/`, no `.gitlab-ci.yml`, no `Jenkinsfile`, no `Makefile.ci`.

**R10.5 FAIL** — Dependent on R10.4. No CI means no automated artifact production.

---

### R11. Logging and Observability

**R11.1 FAIL** — No `journald.conf` with `Storage=persistent` installed by any recipe. Default poky systemd uses `Storage=auto`, which is volatile when `/var/log/journal` is absent (typically absent in minimal images). Logs lost on reboot.

**R11.2 FAIL** — No oneshot unit captures `dmesg` to `/var/log/dmesg.boot`. Kernel boot messages unavailable after reboot.

**R11.3 FAIL** — No kdump or crash dump configured. Per the requirement spec, this is noted but not a hard requirement for v1. Not blocking.

**R11.4 FAIL** — Pinnacle-Client is absent from the image (C3), so the journald access mechanism cannot be evaluated. Even setting that aside, no recipe adds the `pinnacle` user to the `systemd` group or grants `journalctl` read permissions.

---

### R12. Security Hygiene

**R12.1 FAIL** — `core-image-full-cmdline.bbappend` lines 104–107 set password hash for user `pinnacle` with comment `password 'pinnacle'`. Root account status: poky's `core-image-full-cmdline` typically locks root; not explicitly verified in this layer.

**R12.2 PASS** — No private keys committed. `wpa_supplicant-wlan0.conf` has placeholder comments only, no PSK. `kas/repos/` contain only public repo URLs.

**R12.3 FAIL** — `EXTRA_USERS_PARAMS` line 105: `useradd -m -s /bin/bash -G sudo pinnacle`. User `pinnacle` has unrestricted `sudo`. Password `pinnacle` is committed as a hash in a public-adjacent layer. This is a default credential with root escalation.

**R12.4 FAIL** — No firewall (nftables, iptables, or ufw) recipe in meta-pinnacle. swupdate web UI is on port 8080 with no authentication. SSH is open with password auth. Per the requirement, "lab subnet" is accepted as the boundary, but given C2 and C4, the boundary is the only protection.

**R12.5 FAIL** — No signing keys referenced, generated, or configured anywhere in the repo. No `.gitignore` entry for a keys directory. Signing is not implemented (see C2).

---

## Recommended Fix Order

1. **C1 — Implement boot fallback (U-Boot bootcount or initramfs counter).**  
   Reason: Without this, every OTA is a potential permanent brick. Nothing else matters if boards can't self-recover.

2. **C4 — Remove default password, disable SSH password auth.**  
   Reason: Combined with the unauthenticated web UI, any lab network machine can own any board. Fix takes hours, risk is immediate.

3. **C2 — Implement swupdate signing.**  
   Reason: Unsigned OTA over HTTP is an easy attack vector in any shared lab network. After C4 is fixed, this is the remaining code-execution path.

4. **C3 — Add Pinnacle-Client recipe and systemd unit.**  
   Reason: The device's primary application is missing. The OS cannot fulfill its purpose.

5. **I5 / R4.5 — Persistent journald storage.**  
   Reason: Without logs that survive reboot, diagnosing failures from findings 1–4 is much harder.

6. **I1 / R5.3 — Pin all layer commits and fix AUTOREV on pinnacle-hal.**  
   Reason: Non-reproducible builds compound every other problem (can't bisect, can't certify a build).

7. **I3 / R2.6 — Add kernel and DTB to OTA payload.**  
   Reason: An OTA mechanism that can't update the kernel is incomplete. Required before any kernel-requiring feature ships.

8. **I4 / R4.3–R4.4 — Extend health-check to verify application stack before confirming slot.**  
   Reason: The bootcheck service provides no actual health assurance. Implement after C3 and C1 are done.

9. **I6 / R7.1 — Define and implement persistent data partition for Pinnacle-Client.**  
   Reason: Client spool and config need a stable location that survives OTA. Define this before client is added (C3) to avoid rework.

10. **I8 / R10.4–R10.5 — Add CI.**  
    Reason: Every finding above is a defect that CI would catch on regression. Long-term leverage.

11. **M-series findings** — Address in order of operational impact: M6 (text editor), M12 (dmesg capture), M7 (NTP config), M10 (disk monitoring), M5 (protobuf-compiler removal), M8 (factory reset), M11 (sshd hardening config), M3 (dedicated image recipe), M4 (pinnacle-hal HTTPS + pinned SRCREV), M9 (documentation consistency), M1 (machine config docs), M2 (local.conf.sample).

---

## Open Questions for Sandesh

1. **Bootloader choice:** Is there a reason U-Boot was not adopted for the FRDM i.MX 93? The `U-Boot bootcount` mechanism in the NXP i.MX firmware bootloader is functionally equivalent for A/B and simpler to integrate. Confirm which path to pursue for C1: `U-Boot bootcount` (simpler, i.MX 93-specific) or initramfs boot counter (more general, more code).

2. **Pinnacle-Client repo:** What is the GitHub URL and branch for Pinnacle-Client? Is it structurally similar to Pinnacle-HAL (CMake project)? Does it have a daemon mode or is it a one-shot binary?

3. **pinnacle-hal daemon vs. library:** Is `pinnacle-hal` a shared library consumed by `pinnacle-client`, or does it run as a standalone daemon? This determines whether R4.1 is truly PARTIAL or N/A.

4. **Multi-board A/B OTA:** Is A/B OTA intended only for FRDM i.MX 93 and CM5, or is it expected on all 17 supported boards? Several older boards (i.MX 93 1, i.MX 93 Zero) likely lack storage for dual 8 GB rootfs slots.

5. **Lab network model:** Is the swupdate web UI intended to be accessible from any lab machine, or is it meant to be restricted to a management VLAN? This determines whether a firewall rule or HTTP authentication is the right mitigation for C2/I7.

6. **User model:** Should `pinnacle` be a service account (no interactive login, no sudo) and a separate admin user be provisioned with a specific key? Or is `pinnacle` the intended operator account?

7. **Persistent data location:** Is `/var/lib/pinnacle` the intended mount point for client spool, or is there a different convention used in the Pinnacle project? Does the client write a database, flat files, or sockets?

8. **Signing infrastructure:** Is there an existing PKI or key management system in the org, or would keys need to be generated from scratch? Is air-gapped signing a requirement (sign on a dedicated machine, not CI)?
