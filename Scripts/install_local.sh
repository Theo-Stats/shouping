#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$ROOT/build/守屏.app"
TARGET_APP="/Applications/守屏.app"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "请先运行 Scripts/build_app.sh" >&2
  exit 1
fi

pkill -x Shouping 2>/dev/null || true
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
open "$TARGET_APP"
echo "Installed: $TARGET_APP"
