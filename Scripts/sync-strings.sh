#!/bin/bash
# Regenerates Sources/Lowtech/Resources/Lowtech.xcstrings from the strings that the compiler
# extracts out of every Lowtech target. xcodebuild never syncs a catalog by itself, and the
# catalog is shipped uncompiled, so it has to be updated with xcstringstool.
#
# Usage: Scripts/sync-strings.sh [derived data folder]

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CATALOG="$ROOT/Sources/Lowtech/Resources/Lowtech.xcstrings"
DERIVED="${1:-${TMPDIR:-/tmp}/LowtechStrings}"

xcodebuild \
    -scheme Lowtech-Package \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    SWIFT_EMIT_LOC_STRINGS=YES \
    build -quiet

# Only the strings that Lowtech looks up in its own table belong in the catalog
STRINGSDATA=()
while IFS= read -r -d '' f; do
    STRINGSDATA+=("$f")
done < <(find "$DERIVED/Build/Intermediates.noindex/Lowtech.build" -path '*/Lowtech*-t.build/*' -name '*.stringsdata' -print0)

if [[ ${#STRINGSDATA[@]} -eq 0 ]]; then
    echo "No .stringsdata files found under $DERIVED" >&2
    exit 1
fi

xcrun xcstringstool sync "$CATALOG" --stringsdata "${STRINGSDATA[@]}"

echo "Synced $(jq '.strings | length' "$CATALOG") strings into $CATALOG"
