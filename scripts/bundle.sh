#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/Loupe.app"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swift build --package-path "$root" -c release

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/.build/release/Loupe" "$app/Contents/MacOS/Loupe"

swift "$root/scripts/make-icon.swift" "$work/icon.png"
mkdir "$work/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$work/icon.png" --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$work/icon.png" --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$work/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Loupe</string>
  <key>CFBundleDisplayName</key><string>Loupe</string>
  <key>CFBundleIdentifier</key><string>app.loupe.Loupe</string>
  <key>CFBundleExecutable</key><string>Loupe</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Loupe shows your camera in a bubble while you record.</string>
  <key>NSMicrophoneUsageDescription</key><string>Loupe records your voice with your screen.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier app.loupe.Loupe --requirements '=designated => identifier "app.loupe.Loupe"' "$app"
echo "$app"
