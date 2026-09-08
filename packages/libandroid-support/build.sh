TERMUX_PKG_HOMEPAGE=https://github.com/termux/libandroid-support
TERMUX_PKG_DESCRIPTION="Empty library for compatibility, its functions are provided by bionic"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION=28
TERMUX_PKG_REVISION=1
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_SKIP_SRC_EXTRACT=true

termux_step_make() {
	# Everything this used to provide comes from bionic itself now, but the library still
	# has to exist as a loadable ELF: "-landroid-support" must keep resolving when building,
	# and binaries carrying a DT_NEEDED entry for it must keep starting.
	echo | $CC $CPPFLAGS $CFLAGS $LDFLAGS -shared -x c - \
		-Wl,-soname,libandroid-support.so \
		-o "$TERMUX_PKG_BUILDDIR/libandroid-support.so"
}

termux_step_make_install() {
	install -Dm600 "$TERMUX_PKG_BUILDDIR/libandroid-support.so" \
		"$TERMUX_PREFIX/lib/libandroid-support.so"
}
