# linux-imx-headers uses a git:// SRC_URI. In walnascar, git sources are
# cloned to ${UNPACKDIR}/git (i.e. ${WORKDIR}/sources-unpack/git), but
# the default S = ${WORKDIR}/${BPN}-${PV} points to a non-existent directory.
S = "${UNPACKDIR}/git"
