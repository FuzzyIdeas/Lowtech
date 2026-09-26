#!/bin/bash
# Builds a macOS-only Sentry.xcframework (x86_64 + arm64) from a sentry-cocoa release,
# uploads it to files.lowtechguys.com and points Package.swift at it.
#
#   Scripts/slim-sentry.sh 9.29.0
set -euo pipefail

VERSION="${1:?usage: $0 <sentry-cocoa version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="Sentry-macOS-$VERSION.xcframework.zip"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

curl -fsSL "https://github.com/getsentry/sentry-cocoa/releases/download/$VERSION/Sentry.xcframework.zip" -o full.zip
ditto -x -k full.zip full

FW="$(find full -path '*/macos-*/Sentry.framework' -maxdepth 3 -type d | head -1)"
cp -a "$FW" Sentry.framework
lipo Sentry.framework/Versions/A/Sentry -remove arm64e -output Sentry.thin
mv Sentry.thin Sentry.framework/Versions/A/Sentry
rm -f Sentry.framework/Versions/A/Modules/Sentry.swiftmodule/arm64e-*

xcodebuild -create-xcframework -framework "$WORK/Sentry.framework" -output Sentry.xcframework >/dev/null
ditto -c -k --sequesterRsrc --keepParent Sentry.xcframework "$ZIP"
CHECKSUM="$(swift package compute-checksum "$ZIP")"

rsync -avz "$ZIP" hetzner:/static/lowtechguys/

sed -i '' -E \
    -e "s|Sentry-macOS-[0-9.]+\.xcframework\.zip|$ZIP|" \
    -e "/$ZIP/{n;s|checksum: \"[0-9a-f]+\"|checksum: \"$CHECKSUM\"|;}" \
    "$ROOT/Package.swift"

echo "$ZIP $CHECKSUM"
