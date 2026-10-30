#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
use_ai=1
[[ "${1:-}" == "--no-ai" ]] && use_ai=0
"$here/export.sh"
cd "$here" && python3 -m upgrade_editor validate
echo "Spiel -> App: Kontext exportiert, Dokument gültig."
if [[ $use_ai -eq 1 ]]; then
  cd "$root"
  ${CLAUDE_CMD:-claude} -p "$(cat "$here/prompts/game-to-app.md")"
fi
