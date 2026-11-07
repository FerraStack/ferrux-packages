#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Prints the packages (directory names under packages/) needed to build every
# package in a list file, dependencies first, each once.
#
# Usage: ferrux/buildorder.sh [LIST_FILE]   (default: ferrux/packages.txt)
# TERMUX_ARCH selects arch-specific dependencies (default aarch64).
set -euo pipefail
cd "$(dirname "$(realpath "$0")")/.."
list=${1:-ferrux/packages.txt}

declare -A seen=()
emit() {
	if [[ -z "${seen[$1]:-}" ]]; then
		seen[$1]=1
		echo "$1"
	fi
}

while read -r pkg; do
	pkg=${pkg%%#*}
	pkg=${pkg//[[:space:]]/}
	[[ -n "$pkg" ]] || continue
	if [[ ! -d "packages/$pkg" ]]; then
		# A subpackage (e.g. curl from libcurl): build its parent.
		sub=$(compgen -G "packages/*/$pkg.subpackage.sh" | head -n1 || true)
		[[ -n "$sub" ]] || { echo "unknown package: $pkg" >&2; exit 1; }
		pkg=$(basename "$(dirname "$sub")")
	fi
	# buildorder.py prints "<name> <dir>" for the dependencies only.
	while read -r _name dir; do
		[[ -n "${dir:-}" ]] && emit "$(basename "$dir")"
	done < <(python3 scripts/buildorder.py "packages/$pkg" packages)
	emit "$pkg"
done < "$list"
