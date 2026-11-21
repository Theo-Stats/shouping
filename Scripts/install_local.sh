#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$ROOT/build/守屏.app"
TARGET_DIR="/Applications/守屏系统组件"
TARGET_APP="$TARGET_DIR/守屏.app"
LEGACY_APP="/Applications/守屏.app"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "请先运行 Scripts/build_app.sh" >&2
  exit 1
fi

pkill -x Shouping 2>/dev/null || true
mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_APP" "$LEGACY_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
touch "$TARGET_DIR/.metadata_never_index"
open "$TARGET_APP"
echo "Installed: $TARGET_APP"
