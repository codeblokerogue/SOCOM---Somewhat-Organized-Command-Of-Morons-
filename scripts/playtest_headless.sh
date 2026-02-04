#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${ROOT_DIR}/playtest_headless.log"
GODOT_BIN="${ROOT_DIR}/.tools/godot/godot"

echo "[playtest] Installing Godot runtime..."
"${ROOT_DIR}/scripts/install_godot.sh"

if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "[playtest] ERROR: Godot binary not found at ${GODOT_BIN}"
  exit 2
fi

echo "[playtest] Starting headless playtest (log: ${LOG_FILE})"
set +e
"${GODOT_BIN}" --headless --path "${ROOT_DIR}" -- --playtest 2>&1 | tee "${LOG_FILE}"
playtest_status=${PIPESTATUS[0]}
set -e

if [[ ${playtest_status} -ne 0 ]]; then
  echo "[playtest] ERROR: Playtest exited with status ${playtest_status}"
  exit "${playtest_status}"
fi

if command -v rg >/dev/null 2>&1; then
  log_check_cmd=(rg -q)
else
  log_check_cmd=(grep -q)
fi

if "${log_check_cmd[@]}" "Playtest failed:" "${LOG_FILE}"; then
  echo "[playtest] ERROR: Failure detected in logs"
  exit 1
fi

if ! "${log_check_cmd[@]}" "Playtest completed; exiting with code 0" "${LOG_FILE}"; then
  echo "[playtest] ERROR: Success line missing from logs"
  exit 1
fi

echo "[playtest] Success: Playtest completed"
