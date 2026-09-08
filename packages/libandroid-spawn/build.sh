TERMUX_PKG_HOMEPAGE=https://man7.org/linux/man-pages/man3/posix_spawn.3.html
TERMUX_PKG_DESCRIPTION="Empty library for compatibility, posix_spawn is provided by bionic"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_VERSION=0.4
TERMUX_PKG_REVISION=2
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_SKIP_SRC_EXTRACT=true

termux_step_make() {
	# Everything this used to provide comes from bionic itself now, but the library still
	# has to exist as a loadable ELF: "-landroid-spawn" must keep resolving when building,
	# and binaries carrying a DT_NEEDED entry for it must keep starting.
	echo | $CC $CPPFLAGS $CFLAGS $LDFLAGS -shared -x c - \
		-Wl,-soname,libandroid-spawn.so \
		-o "$TERMUX_PKG_BUILDDIR/libandroid-spawn.so"
}

termux_step_make_install() {
	install -Dm600 "$TERMUX_PKG_BUILDDIR/libandroid-spawn.so" \
		"$TERMUX_PREFIX/lib/libandroid-spawn.so"
}
