# u-boot-imx-tools' git source is constructed via ${UBOOT_SRC}, so bitbake
# cannot auto-derive S; it falls back to the (nonexistent) tarball dir and
# do_populate_lic fails to find Licenses/gpl-2.0.txt. Pin S to the git checkout.
S = "${UNPACKDIR}/git"
