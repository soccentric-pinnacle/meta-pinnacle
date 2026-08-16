SUMMARY = "Pinnacle persistent home directory initialisation"
DESCRIPTION = "Creates /home/pinnacle on first boot after the persistent home \
partition (p4) is mounted at /home."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://pinnacle-data-init.sh \
    file://pinnacle-data-init.service \
"

inherit systemd

SYSTEMD_SERVICE:${PN}     = "pinnacle-data-init.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} = "bash util-linux parted e2fsprogs-resize2fs"

do_install() {
    install -d ${D}${libdir}/pinnacle-data-init
    install -m 0755 ${UNPACKDIR}/pinnacle-data-init.sh \
                    ${D}${libdir}/pinnacle-data-init/pinnacle-data-init.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/pinnacle-data-init.service \
                    ${D}${systemd_system_unitdir}/pinnacle-data-init.service
}

FILES:${PN} += " \
    ${libdir}/pinnacle-data-init/ \
    ${systemd_system_unitdir}/pinnacle-data-init.service \
"
