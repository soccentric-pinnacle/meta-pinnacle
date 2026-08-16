# os-release_%.bbappend — identify this image as "Pinnacle OS".
DISTRO_NAME  = "Pinnacle OS"
DISTRO_VERSION = "${PV}"
PRETTY_NAME = "Pinnacle OS ${PV}"
OS_RELEASE_FIELDS:append = " ID_LIKE"
ID_LIKE = "poky"

do_install:append() {
    cat > ${D}${sysconfdir}/os-release <<OSEOF
ID=pinnacle
ID_LIKE=poky
NAME="Pinnacle OS"
VERSION="${PV}"
VERSION_ID="${PV}"
PRETTY_NAME="Pinnacle OS ${PV}"
HOME_URL="https://pinnacle.dev/"
SUPPORT_URL="https://pinnacle.dev/support"
BUG_REPORT_URL="https://pinnacle.dev/issues"
OSEOF
}
