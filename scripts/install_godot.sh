#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools/godot"
BIN_PATH="$TOOLS_DIR/godot"
VERSION="4.2.2"
ARCHIVE_NAME="Godot_v${VERSION}-stable_linux.x86_64.zip"
DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable/${ARCHIVE_NAME}"

if [[ -x "$BIN_PATH" ]]; then
  echo "Godot already installed at $BIN_PATH"
  exit 0
fi

mkdir -p "$TOOLS_DIR"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

archive_path="$tmp_dir/$ARCHIVE_NAME"

echo "Downloading Godot $VERSION..."
if command -v curl >/dev/null 2>&1; then
  curl -L "$DOWNLOAD_URL" -o "$archive_path"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$archive_path" "$DOWNLOAD_URL"
else
  echo "Error: curl or wget is required to download Godot." >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "Error: unzip is required to extract Godot." >&2
  exit 1
fi

unzip -q "$archive_path" -d "$tmp_dir"

extracted_bin="$tmp_dir/Godot_v${VERSION}-stable_linux.x86_64"
if [[ ! -f "$extracted_bin" ]]; then
  echo "Error: expected binary not found after extraction." >&2
  exit 1
fi

mv "$extracted_bin" "$BIN_PATH"
chmod +x "$BIN_PATH"

echo "Godot installed to $BIN_PATH"
