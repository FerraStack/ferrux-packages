# Ferrux packages

This is the package build repository for [Ferrux](https://github.com/FerraStack/ferrux),
a terminal emulator and Linux environment for Android. It is a fork of
[termux-play-store/termux-packages](https://github.com/termux-play-store/termux-packages)
(itself a fork of [termux/termux-packages](https://github.com/termux/termux-packages)),
chosen because it already carries the patches for running programs through
`/system/bin/linker64` (needed at targetSdk ≥ 29) and builds for API level 30.

Packages here are built for the app id **`dev.ferrux`**, so the prefix is
`/data/data/dev.ferrux/files/usr`. Termux packages cannot be mixed in: the
prefix is compiled into every binary.

## What differs from upstream

| File | Change |
|---|---|
| `scripts/properties.sh` | `TERMUX_APP__PACKAGE_NAME` and `TERMUX_REPO_*` set to `dev.ferrux` |
| `repo.json` | Points at this repository (never at termux.net, so no com.termux package can leak into a build) |
| `packages/apt/build.sh` | Ships `etc/apt/sources.list.d/ferrux.sources` for our repository |
| `packages/termux-keyring/` | Contains only the Ferrux signing key (`ferrux-packages.gpg`) |
| `build-package.sh` | Uses `ferrux-packages.gpg` for `-i` downloads |
| `scripts/generate-bootstraps.sh` | `--flat-repository URL` (`@ARCH@` placeholder); no `command-not-found` |
| `ferrux/`, `.github/workflows/ferrux-*.yml` | Build, publish and bootstrap automation (below) |

## The apt repository

One **flat** repository per architecture, stored as the assets of the GitHub
Release `repo-<arch>`:

```
Types: deb
URIs: https://github.com/FerraStack/ferrux-packages/releases/download/repo-aarch64/
Suites: /
Signed-By: /data/data/dev.ferrux/files/usr/etc/apt/trusted.gpg.d/ferrux-packages.gpg
```

Why Releases: free, no bandwidth cap, 2 GiB per file, no 1 GB site limit like
GitHub Pages. Release assets cannot be in directories, hence the flat layout
(`InRelease`, `Packages(.xz)` and the debs side by side) and one release per
architecture. Asset names are sanitised (`libc++` → `libc__`); the `Filename:`
field in `Packages` points at the sanitised name. If the repository outgrows
Releases, the same files can move to object storage (for example Cloudflare R2)
behind a domain without changing the build.

The signing key is RSA 4096, fingerprint
`3D33 FD41 BDB1 1FA5 5B5D  A331 AB13 AF01 501B 3FB0`, valid until 2031-11.
The public key is in `ferrux/ferrux-packages.asc` and
`packages/termux-keyring/ferrux-packages.gpg`. The private key exists only as
the Actions secret `FERRUX_APT_SIGNING_KEY` (with `FERRUX_APT_SIGNING_KEY_ID`).

## Building

Everything heavy runs in CI (`.github/workflows/ferrux-packages.yml`), on every
push that touches recipes or build scripts, or by hand:

1. **Segments 1–3** (each a matrix over aarch64 and x86_64): restore the
   published debs into `output/` (`ferrux/fetch-repo.sh`), build what is
   missing from `ferrux/packages.txt` and its dependencies, one package per
   `build-package.sh` call in the termux-packages Docker image
   (`ferrux/build.sh`), and publish (`ferrux/publish-repo.sh`). A segment stops
   starting new packages after 5 h 15 min, so three chained segments give a
   cold build about 16 h; later runs rebuild only changed packages.
2. **Bootstrap**: `scripts/generate-bootstraps.sh --flat-repository …` assembles
   `bootstrap-<arch>.zip` from the *published* debs, so the bootstrap always
   matches the repository.
3. **Publish bootstrap**: if the bootstrap's package list or versions changed,
   create the release `bootstrap-YYYY.MM.DD-rN` with both zips, `SHA256SUMS`
   and `manifest.txt`. The Ferrux app pins one of these by URL and SHA-256.

To add a package, add its directory name to `ferrux/packages.txt`.
`ferrux/buildorder.sh` prints the resulting build order.

## Licences

As upstream: build infrastructure outside the package directories is
Apache-2.0; each package's recipe and patches carry the package's own licence
(see `LICENSE.md`). GPL packages are distributed with their sources available
from the URLs in their `build.sh`.
