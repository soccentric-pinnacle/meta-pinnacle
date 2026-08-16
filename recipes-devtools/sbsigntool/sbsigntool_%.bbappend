# meta-imx's sbsigntool_0.9.5.bb pins SRCREV 9cfca9f but ships patches written
# against a different revision. The patches do not apply (do_patch fails), so
# they are dropped here. With two git:// SRC_URI entries bitbake cannot
# auto-derive S either, so it is pinned explicitly.
S = "${UNPACKDIR}/git"

# The dropped 0002 patch disabled building man pages; that needs help2man,
# so provide it rather than regenerating the patch.
DEPENDS:append = " help2man-native"

# The dropped 0001 patch disabled configure's hardcoded gnu-efi crt-path check
# (which always fails in OE because the crt0 objects are not in the standard
# system paths). Re-apply that behaviour by replacing the check with a no-op
# before autoreconf runs. The replacement is exact and idempotent.
do_configure:prepend() {
    perl -0pi -e 's/\nif test -z "\$CRTPATH"; then\n   AC_MSG_ERROR\(\[cannot find the gnu-efi crt path\]\)\nfi/\n# gnu-efi crt-path check disabled (embedded)/' \
        ${S}/configure.ac
}

SRC_URI:remove = "file://0001-configure-Dont-t-check-for-gnu-efi.patch"
SRC_URI:remove = "file://0002-docs-Don-t-build-man-pages.patch"
SRC_URI:remove = "file://0003-sbsign-add-x-option-to-avoid-overwrite-existing-sign.patch"
SRC_URI:remove = "file://0004-src-Makefile.am-Add-read_write_all.c-to-common_SOURC.patch"
SRC_URI:remove = "file://0005-fileio.c-initialize-local-variables-before-use-in-fu.patch"
SRC_URI:remove = "file://0006-Makefile.am-do-not-use-Werror.patch"
