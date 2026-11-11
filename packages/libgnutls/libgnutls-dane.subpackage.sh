TERMUX_SUBPKG_INCLUDE="include/gnutls/dane.h lib/libgnutls-dane.so lib/pkgconfig/gnutls-dane.pc"
TERMUX_SUBPKG_DEPENDS="libunbound"
# Ferrux: one line. A newline here produced an invalid control file and
# Packages index ("field name 'Commandline' must be followed by colon").
TERMUX_SUBPKG_DESCRIPTION="DANE protocol implementation for GnuTLS"
