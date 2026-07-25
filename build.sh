#!/usr/bin/env bash

set -eu

OUTPUT="${1:-texture-map-gen}.aseprite-extension"
TEMP_FILE="${OUTPUT}.tmp.zip"

for item in LICENSE package.json src; do
    if [ ! -e "$item" ]; then
        echo "Error: missing '$item' in the current folder." >&2
        exit 1
    fi
done

if [ ! -f LICENSE ] || [ ! -f package.json ] || [ ! -d src ]; then
    echo "Error: LICENSE and package.json must be files, and src must be a directory." >&2
    exit 1
fi

rm -f "$TEMP_FILE"
zip -qr "$TEMP_FILE" LICENSE package.json src
mv -f "$TEMP_FILE" "$OUTPUT"

echo "Created: $OUTPUT"
