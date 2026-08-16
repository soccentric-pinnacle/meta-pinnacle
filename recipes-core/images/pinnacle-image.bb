SUMMARY = "Pinnacle OS — production image for NXP i.MX 8M/9"
DESCRIPTION = "Full image with A/B OTA, gRPC/Protobuf, Pinnacle-HAL (A-core \
+ M-core RPMsg/OpenAMP), hardware interface tooling, and connectivity."
HOMEPAGE = "https://github.com/SiliconCentric/Pinnacle-OS"
LICENSE = "MIT"

# Base on core-image-full-cmdline (provides bash, sshd-openssh,
# package-management, base IMAGE_INSTALL framework).
require recipes-extended/images/core-image-full-cmdline.bb
IMAGE_FEATURES += "ssh-server-openssh"

# OTA / swupdate
# pinnacle-swupdate-config implements the inactive-slot, boot-selection, and
# rollback flow for sdimage-imx93.wks.
IMAGE_INSTALL:append:imx93-11x11-lpddr4x-frdm = " swupdate swupdate-www pinnacle-swupdate-config"

# Home partition init (persistent /home on the data partition)
IMAGE_INSTALL:append = " pinnacle-data-init"

# Root filesystem expansion (single-partition deployments)
IMAGE_INSTALL:append = " expand-rootfs"

# Connectivity
IMAGE_INSTALL:append = " \
    pinnacle-connectivity iw rfkill bluez5-dev \
"

# gRPC + Protobuf via packagegroup-pinnacle-middleware
IMAGE_INSTALL:append = " packagegroup-pinnacle-middleware sudo"

# Cloud/telemetry package group (not installed by default; add via
# packagegroup-pinnacle-cloud when deployments need MQTT/NTP/cloud connectivity)
# IMAGE_INSTALL:append = " packagegroup-pinnacle-cloud"

# Hardware interface tools
IMAGE_INSTALL:append = " \
    i2c-tools python3-smbus python3-smbus2 \
    spitools python3-spidev \
    libgpiod libgpiod-tools python3-gpiod \
    picocom minicom python3-pyserial \
    usbutils pciutils nvme-cli sg3-utils hdparm mtd-utils \
    can-utils \
    lshw ethtool devmem2 cpupower watchdog sysstat iotop strace \
    v4l-utils evtest python3-periphery vim \
"

# Pinnacle stack — HAL includes A-core (Linux) + M-core (RPMsg/OpenAMP) domains
IMAGE_INSTALL:append = " pinnacle-hal pinnacle-services"

# Target debugging and profiling
IMAGE_FEATURES += "tools-debug"
IMAGE_INSTALL:append = " gdbserver perf trace-cmd valgrind"

# Ptest package and runner support
IMAGE_FEATURES += "ptest-pkgs"

# Operator account — locked, SSH-key access only
inherit extrausers
EXTRA_USERS_PARAMS = "\
    useradd -M -s /bin/bash -G sudo pinnacle; \
    usermod -L pinnacle; \
"
