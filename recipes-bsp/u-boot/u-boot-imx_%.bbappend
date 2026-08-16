# u-boot-imx's git source is constructed via ${UBOOT_SRC}, so bitbake cannot
# auto-derive S; it falls back to the tarball dir and do_populate_lic fails to
# find Licenses/gpl-2.0.txt. Pin S to the git checkout.
S = "${UNPACKDIR}/git"

# Provide the boot script source that u-boot.inc compiles into boot.scr when
# UBOOT_ENV = "boot" and UBOOT_ENV_SUFFIX = "scr" are set (kas/common.yaml).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://boot.cmd"
