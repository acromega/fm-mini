#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || true)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
if [[ -z "$MACOS_MAJOR" || "$MACOS_MAJOR" -lt 27 ]]; then
  print -u2 "FM Mini nécessite macOS 27 ou ultérieur (détecté : ${MACOS_VERSION:-inconnu})."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  print -u2 "FM Mini nécessite un Mac Apple Silicon (arm64)."
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  print -u2 "Les Command Line Tools Apple sont nécessaires. Installez-les avec : xcode-select --install"
  exit 1
fi

cat > /tmp/fmcheck.swift <<'SWIFT'
import FoundationModels
let m = SystemLanguageModel.default
print("availability:", m.availability)
print("contextSize:", m.contextSize)
SWIFT

set +e
FMCHECK_OUTPUT="$(swift /tmp/fmcheck.swift 2>&1)"
FMCHECK_STATUS=$?
set -e
print -r -- "$FMCHECK_OUTPUT"
if [[ $FMCHECK_STATUS -ne 0 || "$FMCHECK_OUTPUT" == *"ModelManagerError error 1008"* || "$FMCHECK_OUTPUT" == *"not available in this context"* ]]; then
  print -u2 "Le modèle n'est pas accessible depuis ce contexte. Lancez ce script depuis l'application Terminal."
  exit 1
fi
if [[ "$FMCHECK_OUTPUT" != *"availability: available"* ]]; then
  print -u2 "Le modèle Apple n'est pas disponible. Activez Apple Intelligence dans Réglages Système et attendez la fin du téléchargement."
  exit 1
fi

swift build -c release

APP="$ROOT/build/FM Mini.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/fr.lproj"
cp "$ROOT/.build/release/FMMini" "$APP/Contents/MacOS/FMMini"
cp "$ROOT/Resources/credits.jpg" "$APP/Contents/Resources/credits.jpg"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>FMMini</string>
  <key>CFBundleIdentifier</key><string>org.local.fmmini</string>
  <key>CFBundleName</key><string>FM Mini</string>
  <key>CFBundleDevelopmentRegion</key><string>fr</string>
  <key>CFBundleShortVersionString</key><string>1.3.15</string>
  <key>CFBundleVersion</key><string>1.3.15</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
touch "$APP"
print 'Application prête. Ouvrir avec :'
print "open \"$APP\""
