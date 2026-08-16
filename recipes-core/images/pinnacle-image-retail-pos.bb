SUMMARY = "Pinnacle OS image for retail-pos deployments"
DESCRIPTION = "Full-featured embedded Linux image for the NXP i.MX 8M/9 platform with A/B OTA, gRPC, and hardware interface tools, tuned for the retail-pos vertical."
LICENSE = "MIT"

require recipes-core/images/pinnacle-image.bb
require recipes-core/images/pinnacle-image-common.inc

IMAGE_INSTALL:append = "     packagegroup-core-full-cmdline "
