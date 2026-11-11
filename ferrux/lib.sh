# SPDX-License-Identifier: Apache-2.0
# Helpers shared by the ferrux/*.sh scripts (sourced).

# deb_control DEB: prints the deb's control file. Uses ar + tar rather than
# the host's dpkg-deb, which rejects Termux architecture names (x86_64).
deb_control() {
	local member tmp
	member=$(ar t "$1" | grep -m1 '^control\.tar')
	tmp=$(mktemp)
	ar p "$1" "$member" > "$tmp"
	tar -xOf "$tmp" ./control 2> /dev/null || tar -xOf "$tmp" control
	rm -f "$tmp"
}

# deb_fields DEB: prints "<Package> <Version> <Architecture>".
deb_fields() {
	deb_control "$1" | awk -F': *' '
		$1 == "Package" { p = $2 }
		$1 == "Version" { v = $2 }
		$1 == "Architecture" { a = $2 }
		END { print p, v, a }'
}

# deb_check_control DEB: fails if the control file is not valid deb822
# (e.g. a multi-line description without leading spaces), which would
# corrupt the Packages index for every client.
deb_check_control() {
	local bad
	bad=$(deb_control "$1" | grep -nvE '^([A-Za-z0-9][A-Za-z0-9-]*:|[ \t]|$)' || true)
	if [[ -n "$bad" ]]; then
		echo "::error::invalid control file in $(basename "$1"): $bad" >&2
		return 1
	fi
}
