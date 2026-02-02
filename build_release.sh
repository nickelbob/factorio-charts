#!/bin/bash
# Build a release zip for factorio-charts
# Usage: ./build_release.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Get version from info.json
VERSION=$(grep '"version"' info.json | sed 's/.*"version": "\([^"]*\)".*/\1/')
MOD_NAME="factorio-charts"
ZIP_NAME="${MOD_NAME}_${VERSION}"

# Build in parent directory (mods folder)
cd ..

# Clean up any existing build
rm -rf "$ZIP_NAME" "$ZIP_NAME.zip"

# Create build directory
mkdir -p "$ZIP_NAME"

# Copy files
cp -r "$MOD_NAME"/* "$ZIP_NAME/"

# Remove dev/build files
rm -rf "$ZIP_NAME/.git"
rm -rf "$ZIP_NAME/.claude"
rm -rf "$ZIP_NAME/tests"
rm -f "$ZIP_NAME/run_tests.sh"
rm -f "$ZIP_NAME/CLAUDE.md"
rm -f "$ZIP_NAME/build_release.sh"

# Create zip
zip -r "$ZIP_NAME.zip" "$ZIP_NAME"

# Clean up build directory
rm -rf "$ZIP_NAME"

echo "Created $ZIP_NAME.zip"
