# meta-imx's file_5.45.bb ships print_c.patch which does not apply to the
# pinned SRCREV (4cbd5c8f0851201d203755b76cb66ba991ffd8be), causing do_patch
# to fail. The patch only adds a localtime_r() timezone initialisation; the
# file tool works without it, so drop it to allow the build to proceed.
#
# Pin S to the git checkout so do_populate_lic can find COPYING.
S = "${UNPACKDIR}/git"
SRC_URI:remove = "file://print_c.patch"
