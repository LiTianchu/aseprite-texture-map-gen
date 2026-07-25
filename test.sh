#!/usr/bin/env bash

# Create an .env file in the project root with the following content:
# ASEPRITE_BIN="your_path_to_aseprite_executable"

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: environment file not found: $ENV_FILE" >&2
    exit 1
fi

set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

if [ -z "${ASEPRITE_BIN:-}" ]; then
    echo "Error: ASEPRITE_BIN is not set in $ENV_FILE" >&2
    exit 1
fi

if [ ! -x "$ASEPRITE_BIN" ]; then
    echo "Error: Aseprite executable not found or not executable: $ASEPRITE_BIN" >&2
    exit 1
fi

cd "$SCRIPT_DIR"
for test_file in tests/*.lua; do
    echo "Running $test_file"
    "$ASEPRITE_BIN" -b --script "$test_file"
done
