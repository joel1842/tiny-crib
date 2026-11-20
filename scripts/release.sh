#!/bin/sh
set -e
cd "$(dirname "$0")/.."

version="${1:?usage: scripts/release.sh <version>}"
VERSION="$version" scripts/bundle.sh

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R dist/Cribbage.app "$staging/"
ln -s /Applications "$staging/Applications"

dmg="dist/tiny-crib.dmg"
rm -f "$dmg" dist/*.zip
hdiutil create -volname "Tiny Crib" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null
echo "Built $dmg"
