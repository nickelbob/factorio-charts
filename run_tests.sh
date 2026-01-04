#!/bin/bash
# Run factorio-charts tests using factorio-test-harness
#
# Install the harness with:
#   pip install git+https://github.com/nickelbob/factorio-test-harness.git

set -e

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_DIR="$(dirname "$SCRIPT_DIR")"

# Check if factorio-test is installed
if ! command -v factorio-test &> /dev/null; then
    echo "Error: factorio-test-harness not installed"
    echo "Install with: pip install git+https://github.com/nickelbob/factorio-test-harness.git"
    exit 1
fi

# Find Factorio executable (use FACTORIO_PATH env var or auto-detect)
if [ -z "$FACTORIO_PATH" ]; then
    # Try common locations
    if [ -f "$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio" ]; then
        FACTORIO_PATH="$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio"
    elif [ -f "/Applications/factorio.app/Contents/MacOS/factorio" ]; then
        FACTORIO_PATH="/Applications/factorio.app/Contents/MacOS/factorio"
    elif [ -f "$HOME/.steam/steam/steamapps/common/Factorio/bin/x64/factorio" ]; then
        FACTORIO_PATH="$HOME/.steam/steam/steamapps/common/Factorio/bin/x64/factorio"
    elif [ -f "$HOME/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio" ]; then
        FACTORIO_PATH="$HOME/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio"
    else
        echo "Error: Could not find Factorio executable"
        echo "Set FACTORIO_PATH environment variable to the path of your Factorio executable"
        exit 1
    fi
fi

if [ ! -f "$FACTORIO_PATH" ]; then
    echo "Error: Factorio not found at $FACTORIO_PATH"
    echo "Set FACTORIO_PATH environment variable to the correct path"
    exit 1
fi

# Run tests
factorio-test \
    --factorio "$FACTORIO_PATH" \
    --mod-dir "$MODS_DIR" \
    --test-mod "factorio-charts" \
    "$@"
