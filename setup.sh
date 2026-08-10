#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills"

mkdir -p "$DEST"

find "$REPO" -name SKILL.md \
  -not -path '*/node_modules/*' \
  -not -path '*/deprecated/*' \
  -not -path '*/in-progress/*' \
  -not -path '*/personal/*' \
  -print0 |
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"
  ln -sfn "$src" "$target"
  echo "linked $name -> $src"
done
