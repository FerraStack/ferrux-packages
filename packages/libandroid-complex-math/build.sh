TERMUX_PKG_HOMEPAGE=https://android.googlesource.com/platform/bionic/+/refs/heads/master/libm/upstream-netbsd/lib/libm/complex
TERMUX_PKG_DESCRIPTION="Empty library for compatibility, complex math is provided by bionic"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_VERSION="0.3"
TERMUX_PKG_REVISION=2
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_SKIP_SRC_EXTRACT=true

termux_step_make() {
	# Everything this used to provide comes from bionic itself now, but the library still
	# has to exist as a loadable ELF: "-landroid-complex-math" must keep resolving when
	# building, and binaries carrying a DT_NEEDED entry for it must keep starting.
	echo | $CC $CPPFLAGS $CFLAGS $LDFLAGS -shared -x c - \
		-Wl,-soname,libandroid-complex-math.so \
		-o "$TERMUX_PKG_BUILDDIR/libandroid-complex-math.so"
}

termux_step_make_install() {
	install -Dm600 "$TERMUX_PKG_BUILDDIR/libandroid-complex-math.so" \
		"$TERMUX_PREFIX/lib/libandroid-complex-math.so"
}
