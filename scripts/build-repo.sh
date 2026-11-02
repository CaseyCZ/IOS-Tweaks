#!/usr/bin/env bash
set -euo pipefail

# Produce the unsigned APT metadata for a future Sileo/Zebra repo.
# This script intentionally never deploys anything.

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_source="$project_root/dist"
repo_root="$project_root/docs"

for dependency in dpkg-scanpackages apt-ftparchive gzip; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$dependency" >&2
    exit 1
  fi
done

shopt -s nullglob
packages=("$package_source"/*.deb)
if (( ${#packages[@]} == 0 )); then
  printf 'No .deb files in dist/. Build and verify a package first.\n' >&2
  exit 1
fi

mkdir -p "$repo_root/debs"
cp -- "${packages[@]}" "$repo_root/debs/"

(
  cd "$repo_root"
  dpkg-scanpackages -m debs /dev/null > Packages
  gzip -n -9 -c Packages > Packages.gz
  apt-ftparchive -o APT::FTPArchive::Release::Origin='IOS-Tweaks' \
    -o APT::FTPArchive::Release::Label='IOS-Tweaks' \
    -o APT::FTPArchive::Release::Suite='stable' \
    -o APT::FTPArchive::Release::Codename='rootless' \
    release . > Release
)

printf 'APT metadata created under docs/. No files published.\n'
