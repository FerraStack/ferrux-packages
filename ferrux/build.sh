#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Builds the Ferrux package set for one architecture, one package per
# build-package.sh call, inside the termux-packages Docker builder.
#
# Usage: ferrux/build.sh ARCH DEADLINE_EPOCH [LIST_FILE]
#
# - Debs already in output/ (restored from the published repository by
#   ferrux/fetch-repo.sh) are reused: their packages are marked as built, and
#   build-package.sh installs them as dependencies instead of rebuilding.
# - Packages are built dependencies first (ferrux/buildorder.sh). Before each
#   one the deadline is checked, so a CI job stops cleanly before the 6 h cap
#   and the next job (or re-run) continues where this one stopped.
#
# Exit status: 0 = everything built, 2 = stopped at the deadline (more work
# left), 1 = a package failed to build. ferrux/status is written either way.
set -euo pipefail
cd "$(dirname "$(realpath "$0")")/.."

arch=$1
deadline=$2
list=${3:-ferrux/packages.txt}
status_file=ferrux/status
mkdir -p output

mapfile -t order < <(TERMUX_ARCH="$arch" ferrux/buildorder.sh "$list")
echo "[ferrux] ${#order[@]} packages in build order for $arch"

# Mark restored debs as built so build-package.sh skips them. The marker
# holds the full version, as termux_step_start_build compares it.
./scripts/run-docker.sh bash -c '
	set -e
	mkdir -p /data/data/.built-packages
	shopt -s nullglob
	for deb in output/*.deb; do
		name=$(dpkg-deb -f "$deb" Package)
		version=$(dpkg-deb -f "$deb" Version)
		echo "$version" > "/data/data/.built-packages/$name"
	done
	ls /data/data/.built-packages | wc -l | xargs echo "[ferrux] packages marked as built:"
'

built=0
for pkg in "${order[@]}"; do
	now=$(date +%s)
	left=$((deadline - now))
	if ((left < 300)); then
		echo "[ferrux] deadline reached; stopping before $pkg"
		echo "incomplete" > "$status_file"
		exit 2
	fi
	echo "::group::build $pkg ($arch)"
	start=$now
	set +e
	timeout --kill-after=60 "$left" ./scripts/run-docker.sh ./build-package.sh -C -a "$arch" "$pkg"
	rc=$?
	set -e
	echo "::endgroup::"
	if ((rc == 124 || rc == 137)); then
		echo "[ferrux] $pkg hit the deadline after $(($(date +%s) - start)) s"
		echo "incomplete" > "$status_file"
		exit 2
	elif ((rc != 0)); then
		echo "::error::build of $pkg ($arch) failed with status $rc"
		echo "failed $pkg" > "$status_file"
		exit 1
	fi
	echo "[ferrux] $pkg done in $(($(date +%s) - start)) s"
	built=$((built + 1))
	# Free the build tree; sources stay cached in ~/.termux-build/_cache.
	./scripts/run-docker.sh bash -c "rm -rf \"\$HOME/.termux-build/$pkg\"" || true
done

echo "[ferrux] all ${#order[@]} packages present for $arch"
echo "complete" > "$status_file"
