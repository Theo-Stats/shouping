#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/守屏.app"
DMG="$ROOT/build/守屏-${VERSION:-0.5.0}.dmg"

if [[ ! -d "$APP" ]]; then
  echo "请先运行 Scripts/build_app.sh" >&2
  exit 1
fi

rm -f "$DMG"
hdiutil create \
  -volname "守屏" \
  -srcfolder "$APP" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Created: $DMG"
