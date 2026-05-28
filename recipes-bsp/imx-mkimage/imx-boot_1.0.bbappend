# meta-imx's imx-mkimage_git.inc does not set S, causing the git-fetched source
# (unpacked to ${WORKDIR}/sources-unpack/git) to be unreachable during do_patch
# and do_compile since S defaults to ${WORKDIR}/${BPN}-${PV}.
# meta-freescale's version of the same .inc correctly sets this variable.
S = "${WORKDIR}/git"
