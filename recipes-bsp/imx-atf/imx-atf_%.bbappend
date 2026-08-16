# imx-atf's git source is constructed via ${ATF_SRC}, so bitbake cannot
# auto-derive S; it falls back to the empty tarball dir and make finds no
# bl31 target. Pin S to the git checkout.
S = "${UNPACKDIR}/git"
