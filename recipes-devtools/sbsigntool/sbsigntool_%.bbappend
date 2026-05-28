# Walnascar (Yocto 5.2) moved git-fetched sources to ${UNPACKDIR}/git instead
# of ${WORKDIR}/${BP}. The upstream sbsigntool recipe does not set S, so we
# must point it at the correct location.
S = "${UNPACKDIR}/git"
