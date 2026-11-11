TERMUX_PKG_HOMEPAGE=https://github.com/FerraStack/ferrux-packages
TERMUX_PKG_DESCRIPTION="GPG public key for the Ferrux package repository"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_MAINTAINER="FerraStack"
TERMUX_PKG_VERSION=3.15
TERMUX_PKG_REVISION=1
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_SKIP_SRC_EXTRACT=true
TERMUX_PKG_PLATFORM_INDEPENDENT=true
TERMUX_PKG_ESSENTIAL=true

termux_step_make_install() {
	local GPG_SHARE_DIR="$TERMUX_PREFIX/share/termux-keyring"

	# Delete all existing keyring keys
	rm -rf "$GPG_SHARE_DIR"
	mkdir -p "$GPG_SHARE_DIR"

	# Ferrux: only the Ferrux repository key is trusted (ferrux/ferrux-packages.asc
	# is the armored copy). Termux's keys are left out on purpose: Termux packages
	# are built for the com.termux prefix and cannot be installed here.
	install -Dm600 $TERMUX_PKG_BUILDER_DIR/ferrux-packages.gpg $GPG_SHARE_DIR

	GPG_DIR="$TERMUX_PREFIX/etc/apt/trusted.gpg.d"
	mkdir -p "$GPG_DIR"
	for GPG_FILE in "$GPG_SHARE_DIR"/*.gpg; do
		ln -s "$GPG_FILE" "$GPG_DIR/$(basename $GPG_FILE)"
	done
}
