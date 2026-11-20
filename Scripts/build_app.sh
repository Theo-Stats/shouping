#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/守屏.app"
CONFIGURATION="${CONFIGURATION:-release}"

cd "$ROOT"
swift build -c "$CONFIGURATION" --product Shouping
swift build -c "$CONFIGURATION" --product ShoupingAgent
swift run -c "$CONFIGURATION" ShoupingChecks

if [[ "${BUILD_UNIVERSAL:-1}" == "1" ]]; then
  swift build -c "$CONFIGURATION" --arch x86_64 --scratch-path "$ROOT/.build-x86_64" --product Shouping
  swift build -c "$CONFIGURATION" --arch x86_64 --scratch-path "$ROOT/.build-x86_64" --product ShoupingAgent
  lipo -create \
    "$ROOT/.build/$CONFIGURATION/Shouping" \
    "$ROOT/.build-x86_64/x86_64-apple-macosx/$CONFIGURATION/Shouping" \
    -output "$ROOT/.build/$CONFIGURATION/Shouping.universal"
  lipo -create \
    "$ROOT/.build/$CONFIGURATION/ShoupingAgent" \
    "$ROOT/.build-x86_64/x86_64-apple-macosx/$CONFIGURATION/ShoupingAgent" \
    -output "$ROOT/.build/$CONFIGURATION/ShoupingAgent.universal"
  mv "$ROOT/.build/$CONFIGURATION/Shouping.universal" "$ROOT/.build/$CONFIGURATION/Shouping"
  mv "$ROOT/.build/$CONFIGURATION/ShoupingAgent.universal" "$ROOT/.build/$CONFIGURATION/ShoupingAgent"
fi
python3 "$ROOT/Scripts/generate_icon.py"
iconutil -c icns "$ROOT/Resources/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Library/LaunchAgents"
cp "$ROOT/.build/$CONFIGURATION/Shouping" "$APP_DIR/Contents/MacOS/Shouping"
cp "$ROOT/.build/$CONFIGURATION/ShoupingAgent" "$APP_DIR/Contents/MacOS/ShoupingAgent"
cp "$ROOT/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Packaging/com.example.shouping.agent.plist" "$APP_DIR/Contents/Library/LaunchAgents/com.example.shouping.agent.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"
elif [[ -n "${LOCAL_SIGNING_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$LOCAL_SIGNING_IDENTITY"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q '"Shouping Local Development"'; then
  SIGN_IDENTITY="Shouping Local Development"
else
  SIGN_IDENTITY="-"
fi
if [[ "$SIGN_IDENTITY" != "-" && -n "${LOCAL_SIGNING_KEYCHAIN:-}" ]]; then
  codesign --force --options runtime --keychain "$LOCAL_SIGNING_KEYCHAIN" --sign "$SIGN_IDENTITY" "$APP_DIR/Contents/MacOS/ShoupingAgent"
  codesign --force --deep --options runtime --keychain "$LOCAL_SIGNING_KEYCHAIN" --sign "$SIGN_IDENTITY" "$APP_DIR"
else
  codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR/Contents/MacOS/ShoupingAgent"
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
fi
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built: $APP_DIR"
