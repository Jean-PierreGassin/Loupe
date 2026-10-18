#!/usr/bin/env bash
set -euo pipefail

# LOUPE_VERSION            version string, defaults to 0.0.0-dev
# LOUPE_DISTRIBUTION=1     universal binary, signed per build instead of pinned to the identifier
# LOUPE_SIGNING_IDENTITY   signing identity, a Developer ID or a stable self-signed certificate; implies a distribution
#                          build that updates itself
# LOUPE_SIGNING_KEYCHAIN   keychain holding that identity when it isn't on the search list

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/Loupe.app"
identifier="io.github.jean-pierregassin.Loupe"
version="${LOUPE_VERSION:-0.0.0-dev}"
build="$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 1)"
work="$(mktemp -d)"
updates="<false/>"
[[ -n "${LOUPE_SIGNING_IDENTITY:-}" ]] && updates="<true/>"
trap 'rm -rf "$work"' EXIT

build_args=(--package-path "$root" -c release)
if [[ -n "${LOUPE_DISTRIBUTION:-}${LOUPE_SIGNING_IDENTITY:-}" ]]; then
  build_args+=(--arch arm64 --arch x86_64)
fi
swift build "${build_args[@]}"
binary="$(swift build "${build_args[@]}" --show-bin-path)/Loupe"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Loupe"

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
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$build</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Jean-Pierre Gassin. MIT License.</string>
  <key>NSCameraUsageDescription</key><string>Loupe shows your camera in a bubble while you record.</string>
  <key>NSMicrophoneUsageDescription</key><string>Loupe records your voice with your screen.</string>
  <key>LoupeUpdatesEnabled</key>$updates
</dict>
</plist>
PLIST

if [[ -n "${LOUPE_SIGNING_IDENTITY:-}" ]]; then
  sign_args=(--force --options runtime --entitlements "$root/scripts/Loupe.entitlements" --sign "$LOUPE_SIGNING_IDENTITY")
  [[ "$LOUPE_SIGNING_IDENTITY" == "Developer ID Application"* ]] && sign_args+=(--timestamp)
  [[ -n "${LOUPE_SIGNING_KEYCHAIN:-}" ]] && sign_args+=(--keychain "$LOUPE_SIGNING_KEYCHAIN")
  codesign "${sign_args[@]}" "$app"
elif [[ -n "${LOUPE_DISTRIBUTION:-}" ]]; then
  codesign --force --sign - --identifier "$identifier" "$app"
else
  codesign --force --sign - --identifier "$identifier" --requirements "=designated => identifier \"$identifier\"" "$app"
fi
echo "$app"
