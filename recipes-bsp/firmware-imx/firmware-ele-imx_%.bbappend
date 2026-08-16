# meta-imx's fsl-eula-unpack class extracts the .bin into ${WORKDIR}, but this
# recipe points S at ${UNPACKDIR}/... which does not exist, breaking
# do_populate_lic and install. Point S at the actual extraction location.
S = "${WORKDIR}/${BP}-${IMX_SRCREV_ABBREV}"
