# meta-imx's efitools recipe pins SRCREV 392836a but ships patches written
# against a different revision; several do not apply (do_patch fails), and the
# last one (0001-add-binary-only-make-rules.patch) is the only provider of the
# 'binaries' / 'install-binaries' make targets the native recipe relies on.
# Drop the non-applying patches and recreate the make targets here instead.
#
# S is not auto-derived for the git source here, so pin it to UNPACKDIR/git or
# do_populate_lic cannot find COPYING.
S = "${UNPACKDIR}/git"

# Recreate the binaries/install-binaries targets that the dropped patch added,
# and point gnu-efi include paths at the recipe sysroot (INCDIR_PREFIX).
do_compile:prepend() {
    cat >> ${S}/Makefile <<'EOF'

# binaries/install-binaries targets (replaces dropped meta-imx patch)
binaries: $(BINARIES)
install-binaries: binaries
	$(INSTALL) -m 755 -d $(BINDIR)
	$(INSTALL) -m 755 $(BINARIES) $(BINDIR)
	$(INSTALL) -m 755 mkusb.sh $(BINDIR)/efitool-mkusb
EOF
    # gnu-efi headers are in the recipe sysroot, not /usr/include
    sed -i 's|-I/usr/include/efi|-I$(INCDIR_PREFIX)/usr/include/efi|g' \
        ${S}/Make.rules
    # ensure libcrypto is found via OPENSSL_LIB in the link rules (do NOT add
    # $(LDFLAGS) - Make.rules sets it to EFI link flags)
    sed -i -e 's|lib/lib.a -lcrypto|lib/lib.a -L$(OPENSSL_LIB) -lcrypto|g' \
        ${S}/Makefile
}

# efi.h is provided by gnu-efi
DEPENDS:append = " gnu-efi-native"

# efitools' simple_file.c passes an incompatible pointer to StrCat with the
# SDK's gnu-efi; downgrade that error to a warning. Also define _GNU_SOURCE so
# strptime() is declared (the dropped 0002 patch did this).
CFLAGS:append = " -Wno-error=incompatible-pointer-types -D_GNU_SOURCE"

# For the nativesdk variant, build/install only the host binaries (the EFI app
# compilation needs gnu-efi patches that do not apply to this SRCREV).
do_compile:class-nativesdk() {
    oe_runmake binaries
}
do_install:class-nativesdk() {
    oe_runmake install-binaries DESTDIR='${D}${base_prefix}'
}

SRC_URI:remove = "file://0001-Fix-for-the-cross-compilation.patch"
SRC_URI:remove = "file://0002-Make.rules-define-_GNU_SOURCE-for-a-declaration-of-f.patch"
SRC_URI:remove = "file://0003-Fix-the-wrong-dependency-for-blacklist.esl.patch"
SRC_URI:remove = "file://0004-LockDown-run-system-warm-reset-after-the-key-provisi.patch"
SRC_URI:remove = "file://0005-Allow-to-override-tools-for-target-build.patch"
SRC_URI:remove = "file://0006-Makefile-remove-help2man-dependency.patch"
SRC_URI:remove = "file://0007-Add-static-keyword-for-IsValidVariableHeader.patch"
SRC_URI:remove = "file://0008-Dynamically-load-openssl.cnf-for-openssl-1.0.x-1.1.x.patch"
SRC_URI:remove = "file://0009-console.c-Fix-compilation-against-latest-usr-include.patch"
SRC_URI:remove = "file://0010-LockDown-enable-the-enrollment-for-DBX.patch"
SRC_URI:remove = "file://0011-LockDown-show-the-error-message-with-3-sec-timeout.patch"
SRC_URI:remove = "file://0012-Makefile-do-not-build-signed-efi-image.patch"
SRC_URI:remove = "file://0013-Build-DBX-by-default.patch"
SRC_URI:remove = "file://0014-LockDown-disable-the-entrance-into-BIOS-setup-to-re-.patch"
SRC_URI:remove = "file://0015-fix-segfault-for-efitools-commands.patch"
SRC_URI:remove = "file://0016-Make.rules-Pass-CFLAGS-to-Makefile.patch"
SRC_URI:remove = "file://0017-Make.rules-fix-efi-files-for-gnu-efi-3.0.18.patch"
SRC_URI:remove = "file://0001-add-binary-only-make-rules.patch"
