# meta-imx's firmware-imx-8.31.inc uses fsl-eula-unpack which extracts to
# ${WORKDIR}, but S points at ${UNPACKDIR}/... which does not exist. Point S at
# the actual extraction location so do_populate_lic and deploy can find firmware.
S = "${WORKDIR}/firmware-imx-${PV}-${IMX_SRCREV_ABBREV}"
