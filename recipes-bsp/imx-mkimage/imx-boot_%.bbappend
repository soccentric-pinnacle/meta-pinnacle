# meta-imx's imx-mkimage_git.inc pins SRCREV c0debd7 but its
# 0001-iMX8M-soc.mak-use-native-mkimage-from-sysroot.patch does not apply to
# that revision, breaking do_patch. Drop the patch so the boot image builds.
SRC_URI:remove = "file://0001-iMX8M-soc.mak-use-native-mkimage-from-sysroot.patch"

# imx-mkimage's git source is constructed via ${IMX_MKIMAGE_SRC}, so bitbake
# cannot auto-derive S; it falls back to the empty tarball dir. Pin S to git.
S = "${UNPACKDIR}/git"
