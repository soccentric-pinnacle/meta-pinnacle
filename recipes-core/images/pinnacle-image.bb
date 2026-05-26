SUMMARY = "Pinnacle OS image for NXP i.MX93 FRDM board"
DESCRIPTION = "Minimal headless image with SWUpdate A/B OTA, connectivity, \
    and hardware interface tooling."

LICENSE = "MIT"

inherit core-image extrausers

IMAGE_FEATURES += " \
    ssh-server-openssh \
    tools-debug \
"

IMAGE_INSTALL += " \
    swupdate \
    swupdate-www \
    rpi5-swupdate-config \
    wpa-supplicant \
    iw \
    rfkill \
    bluez5 \
    protobuf \
    grpc \
    python3-grpcio \
    python3-protobuf \
    sudo \
    i2c-tools \
    libgpiod \
    libgpiod-tools \
    usbutils \
    pciutils \
    can-utils \
    ethtool \
    strace \
"

EXTRA_USERS_PARAMS = "\
    useradd -m -s /bin/bash -G sudo pinnacle; \
    usermod -p '\$6\$8.kfghMSYkTHsFqs\$fKQIEp.xMjitUYt9yXjEZBUvKqUOQvxekn5.9hWP9ewiLFSI0LQi5OpaDNfSqh4OU.tzN7co7olMAYg53/kCP0' pinnacle; \
"

export IMAGE_BASENAME = "pinnacle-image"
