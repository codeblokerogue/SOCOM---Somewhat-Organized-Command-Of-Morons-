#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.2.2-stable"
GODOT_ARCHIVE="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ARCHIVE}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${ROOT_DIR}/.tools/godot"
INSTALL_PATH="${INSTALL_DIR}/godot"

if [[ -x "${INSTALL_PATH}" ]]; then
  echo "Godot already installed at ${INSTALL_PATH}"
  exit 0
fi

mkdir -p "${INSTALL_DIR}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

archive_path="${tmp_dir}/${GODOT_ARCHIVE}"

echo "Downloading ${GODOT_URL}..."
curl -L --fail -o "${archive_path}" "${GODOT_URL}"

echo "Extracting ${GODOT_ARCHIVE}..."
unzip -q "${archive_path}" -d "${tmp_dir}"

extracted_binary="${tmp_dir}/Godot_v${GODOT_VERSION}_linux.x86_64"
if [[ ! -f "${extracted_binary}" ]]; then
  echo "Expected binary not found at ${extracted_binary}" >&2
  exit 1
fi

mv "${extracted_binary}" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"

echo "Installed Godot to ${INSTALL_PATH}"
