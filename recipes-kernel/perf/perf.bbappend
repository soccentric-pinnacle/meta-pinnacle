# The kernel 6.18 (NXP i.MX) source lacks include/uapi/asm-generic/Kbuild, which
# perf's scripts/Makefile.asm-headers unconditionally includes, breaking
# do_compile. Provide an empty file so the include succeeds (the generic-y list
# ends up empty, which is fine for the Pinnacle image).
do_compile:prepend() {
    mkdir -p ${S}/include/uapi/asm-generic
    : > ${S}/include/uapi/asm-generic/Kbuild
}
