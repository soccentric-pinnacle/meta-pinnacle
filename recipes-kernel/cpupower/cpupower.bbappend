# cpupower installs a systemd unit that is not covered by the default FILES.
# Ship it so the installed-vs-shipped QA check passes.
FILES:${PN} += "${systemd_system_unitdir}/cpupower.service"
