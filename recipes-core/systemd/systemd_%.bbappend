# Persistent journal + explicit NTP for Pinnacle devices.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://journald-pinnacle.conf \
    file://timesyncd-pinnacle.conf \
"

do_install:append() {
    install -d ${D}${sysconfdir}/systemd/journald.conf.d
    install -m 0644 ${UNPACKDIR}/journald-pinnacle.conf \
                    ${D}${sysconfdir}/systemd/journald.conf.d/pinnacle.conf

    install -d ${D}${sysconfdir}/systemd/timesyncd.conf.d
    install -m 0644 ${UNPACKDIR}/timesyncd-pinnacle.conf \
                    ${D}${sysconfdir}/systemd/timesyncd.conf.d/pinnacle.conf
}

FILES:${PN} += " \
    ${sysconfdir}/systemd/journald.conf.d/ \
    ${sysconfdir}/systemd/timesyncd.conf.d/ \
"

INSANE_SKIP:${PN} += "empty-dirs"
