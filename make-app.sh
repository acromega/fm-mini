#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"
swift build -c release

APP="$ROOT/build/FM Mini.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/.build/release/FMMini" "$APP/Contents/MacOS/FMMini"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>FMMini</string>
  <key>CFBundleIdentifier</key><string>org.local.fmmini</string>
  <key>CFBundleName</key><string>FM Mini</string>
  <key>CFBundleShortVersionString</key><string>1.3.1</string>
  <key>CFBundleVersion</key><string>1.3.1</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
print 'Application prête. Ouvrir avec :'
print "open \"$APP\""
