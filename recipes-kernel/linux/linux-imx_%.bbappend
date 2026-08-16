# The kconfiglib (symbol_why.py) shipped with this poky cannot parse the
# kernel 6.18 Kconfig 'transitional' keyword, so do_kernel_configcheck fails.
# The config check is advisory; skip it for the Pinnacle kernel.
do_kernel_configcheck[noexec] = "1"
