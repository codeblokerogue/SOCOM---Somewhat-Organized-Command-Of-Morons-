#!/usr/bin/env bash
set -euo pipefail

./scripts/install_godot.sh
./.tools/godot/godot --headless --path . -- --playtest
