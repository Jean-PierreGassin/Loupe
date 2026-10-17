#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/Loupe.app"
identifier="io.github.jean-pierregassin.Loupe"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swift build --package-path "$root" -c release

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/.build/release/Loupe" "$app/Contents/MacOS/Loupe"

swift "$root/scripts/make-icon.swift" "$root/assets/icon.svg" "$work/icon.png"
mkdir "$work/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$work/icon.png" --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$work/icon.png" --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$work/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Loupe</string>
  <key>CFBundleDisplayName</key><string>Loupe</string>
  <key>CFBundleIdentifier</key><string>$identifier</string>
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

if [[ -n "${LOUPE_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$root/scripts/Loupe.entitlements" --sign "$LOUPE_SIGNING_IDENTITY" "$app"
else
  codesign --force --sign - --identifier "$identifier" --requirements "=designated => identifier \"$identifier\"" "$app"
fi
echo "$app"
