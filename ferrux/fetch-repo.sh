#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Downloads the published debs of one architecture's repository into output/
# under their build-package.sh names (<name>_<version>_<arch>.deb), so
# ferrux/build.sh can reuse them instead of rebuilding.
#
# Usage: ferrux/fetch-repo.sh ARCH        (needs GH_TOKEN and GITHUB_REPOSITORY)
set -euo pipefail
cd "$(dirname "$(realpath "$0")")/.."

arch=$1
tag="repo-$arch"
repo=${GITHUB_REPOSITORY:-FerraStack/ferrux-packages}
mkdir -p output

if ! gh release view "$tag" -R "$repo" > /dev/null 2>&1; then
	echo "[ferrux] no release $tag yet; starting from scratch"
	exit 0
fi

dl=$(mktemp -d)
gh release download "$tag" -R "$repo" -p '*.deb' -D "$dl" --skip-existing
shopt -s nullglob
n=0
for deb in "$dl"/*.deb; do
	name=$(dpkg-deb -f "$deb" Package)
	version=$(dpkg-deb -f "$deb" Version)
	deb_arch=$(dpkg-deb -f "$deb" Architecture)
	mv "$deb" "output/${name}_${version}_${deb_arch}.deb"
	n=$((n + 1))
done
rm -rf "$dl"
echo "[ferrux] restored $n debs from $tag"
