#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Publishes output/*.deb of one architecture as a signed *flat* apt repository
# in the GitHub Release "repo-<arch>":
#
#   deb [signed-by=…/ferrux-packages.gpg] https://github.com/<repo>/releases/download/repo-<arch>/ /
#
# Release assets cannot live in directories, which is why the repository is
# flat (InRelease, Packages and the debs side by side) and split per
# architecture. Asset names are restricted, so each deb is uploaded under a
# sanitised name that the Packages index points to.
#
# Only the newest version of each package is kept. Upload order is debs,
# then indexes, then InRelease, so clients see at most a short window where
# the signed index is older than Packages (apt then retries on next update).
#
# Usage: ferrux/publish-repo.sh ARCH
# Env:   GH_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA, FERRUX_APT_SIGNING_KEY_ID
#        (the private key must already be imported into gpg).
set -euo pipefail
cd "$(dirname "$(realpath "$0")")/.."

arch=$1
tag="repo-$arch"
repo=${GITHUB_REPOSITORY:-FerraStack/ferrux-packages}
key_id=${FERRUX_APT_SIGNING_KEY_ID:?FERRUX_APT_SIGNING_KEY_ID is not set}

sanitize() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }

work=$(mktemp -d)
pool="$work/pool"
meta="$work/meta"
mkdir -p "$pool" "$meta"

# Newest version of each package (arch-specific and arch-independent).
declare -A best_ver=() best_file=()
shopt -s nullglob
for deb in output/*_"$arch".deb output/*_all.deb; do
	name=$(dpkg-deb -f "$deb" Package)
	ver=$(dpkg-deb -f "$deb" Version)
	if [[ -z "${best_ver[$name]:-}" ]] || dpkg --compare-versions "$ver" gt "${best_ver[$name]}"; then
		best_ver[$name]=$ver
		best_file[$name]=$deb
	fi
done
if ((${#best_file[@]} == 0)); then
	echo "[ferrux] nothing to publish for $arch"
	exit 0
fi
for name in "${!best_file[@]}"; do
	deb=${best_file[$name]}
	ln "$deb" "$pool/$(sanitize "$(basename "$deb")")" 2> /dev/null || cp "$deb" "$pool/$(sanitize "$(basename "$deb")")"
done
echo "[ferrux] $tag: ${#best_file[@]} packages"

# Indexes. Filename is relative to the repository URL (the release).
(cd "$pool" && apt-ftparchive packages .) | sed 's|^Filename: \./|Filename: |' > "$meta/Packages"
xz -9 -k "$meta/Packages"
apt-ftparchive \
	-o APT::FTPArchive::Release::Origin="Ferrux" \
	-o APT::FTPArchive::Release::Label="Ferrux" \
	-o APT::FTPArchive::Release::Architectures="$arch all" \
	-o APT::FTPArchive::Release::Description="Ferrux packages for $arch (github.com/$repo)" \
	release "$meta" > "$work/Release"
mv "$work/Release" "$meta/Release"
gpg --batch --yes --local-user "$key_id" --clearsign -o "$meta/InRelease" "$meta/Release"
gpg --batch --yes --local-user "$key_id" --armor --detach-sign -o "$meta/Release.gpg" "$meta/Release"
gpg --batch --verify "$meta/InRelease"

if ! gh release view "$tag" -R "$repo" > /dev/null 2>&1; then
	gh release create "$tag" -R "$repo" --target "${GITHUB_SHA:-main}" --latest=false \
		--title "Ferrux apt repository ($arch)" \
		--notes "Flat apt repository for Ferrux ($arch), signed with the key in ferrux/ferrux-packages.asc. Managed by CI; do not edit by hand.

\`\`\`
deb [signed-by=\$PREFIX/etc/apt/trusted.gpg.d/ferrux-packages.gpg] https://github.com/$repo/releases/download/$tag/ /
\`\`\`"
fi

mapfile -t existing < <(gh release view "$tag" -R "$repo" --json assets --jq '.assets[].name')
declare -A have=()
for a in "${existing[@]}"; do have[$a]=1; done

uploads=()
for f in "$pool"/*.deb; do
	[[ -n "${have[$(basename "$f")]:-}" ]] || uploads+=("$f")
done
echo "[ferrux] uploading ${#uploads[@]} new debs"
# Upload in batches to keep each gh call reasonable.
for ((i = 0; i < ${#uploads[@]}; i += 20)); do
	gh release upload "$tag" -R "$repo" --clobber "${uploads[@]:i:20}"
done
gh release upload "$tag" -R "$repo" --clobber "$meta/Packages" "$meta/Packages.xz" "$meta/Release" "$meta/Release.gpg"
gh release upload "$tag" -R "$repo" --clobber "$meta/InRelease"

# Remove debs that are no longer in the index (superseded versions).
declare -A keep=()
for f in "$pool"/*.deb; do keep[$(basename "$f")]=1; done
for a in "${existing[@]}"; do
	if [[ "$a" == *.deb && -z "${keep[$a]:-}" ]]; then
		echo "[ferrux] removing superseded $a"
		gh release delete-asset "$tag" "$a" -R "$repo" --yes
	fi
done
rm -rf "$work"
echo "[ferrux] published https://github.com/$repo/releases/tag/$tag"
