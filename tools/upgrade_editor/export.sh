#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot="${GODOT:-${G:-$HOME/.local/opt/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}}"
cd "$root"
"$godot" --headless --import >/dev/null 2>&1 || true
"$godot" --headless -s tools/upgrade_editor/export_game.gd
if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  "$godot" --rendering-driver opengl3 -s tools/upgrade_editor/render_map.gd
else
  echo "Kein Display: Kartenbild wird nicht neu gerendert."
fi
