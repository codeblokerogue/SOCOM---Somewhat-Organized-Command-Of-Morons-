#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/Godot" >&2
  exit 1
fi

godot_path="$1"

if [[ ! -x "$godot_path" ]]; then
  echo "Godot binary not found or not executable: $godot_path" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
output_dir="$project_root/builds/playtest"
output_path="$output_dir/SOCOM_Playtest.x86_64"

mkdir -p "$output_dir"

"$godot_path" --headless --path "$project_root" --export-release "Linux/X11" "$output_path"

echo "Playtest build exported to: $output_path"
