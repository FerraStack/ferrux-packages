TERMUX_PKG_HOMEPAGE=https://github.com/termux-play-store/termux-tools
TERMUX_PKG_DESCRIPTION="Basic system tools for Termux"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="3.0.9"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=https://github.com/termux-play-store/termux-tools/archive/refs/tags/${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=d275fbc736c936abc9a8460d4d310d34704406db03405cf96f82a62b082893a9
TERMUX_PKG_ESSENTIAL=true
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_UPDATE_TAG_TYPE="newest-tag"
TERMUX_PKG_SUGGESTS="termux-api"

# Some of these packages are not dependencies and used only to ensure
# that core packages are installed after upgrading (we removed busybox
# from essentials).
TERMUX_PKG_DEPENDS="coreutils, curl, dash, diffutils, findutils, gawk, grep, less, procps, psmisc, sed, tar, termux-am, termux-exec, util-linux"

# Optional packages that are distributed as part of bootstrap archives.
TERMUX_PKG_RECOMMENDS="ed, dos2unix, inetutils, net-tools, patch, unzip"

termux_step_pre_configure() {
	# Can't apply these patch normally since they contains special @TERMUX..@ text which normal patch replaces:
	for d in "$TERMUX_PKG_BUILDER_DIR"/*.diff; do
		patch -p1 < "$d"
	done

	autoreconf -vfi

	# Ferrux: configure.ac reads these from the environment and otherwise falls
	# back to com.termux paths (pkg, login, chsh, termux-info, profile.d, …).
	export TERMUX_APP_PACKAGE="$TERMUX_APP__PACKAGE_NAME"
	export TERMUX_BASE_DIR="$TERMUX__ROOTFS"
	export TERMUX_CACHE_DIR
	export TERMUX_PREFIX
	export TERMUX_ANDROID_HOME="$TERMUX__HOME"
}
