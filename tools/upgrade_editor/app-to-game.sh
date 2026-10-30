#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
use_ai=1
[[ "${1:-}" == "--no-ai" ]] && use_ai=0
cd "$here"
python3 -m upgrade_editor changes > "$here/data/last_changes.jsonl" || true
python3 -m upgrade_editor validate
python3 -m upgrade_editor apply
echo "App -> Spiel: bearbeitete Kopie übernommen (Original archiviert, Texte aktualisiert)."
if [[ $use_ai -eq 1 ]]; then
  cd "$root"
  ${CLAUDE_CMD:-claude} -p "$(cat "$here/prompts/app-to-game.md")"
fi
