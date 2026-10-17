#!/usr/bin/env bash
set -euo pipefail

# Builds dist/Loupe-<version>.dmg. Takes the same environment as bundle.sh, plus
# LOUPE_NOTARY_PROFILE, a notarytool keychain profile used to notarize and staple a Developer ID build, and
# LOUPE_NOTARY_KEYCHAIN, the keychain holding that profile when it isn't the default one.

root="$(cd "$(dirname "$0")/.." && pwd)"
version="${LOUPE_VERSION:-0.0.0-dev}"
dmg="$root/dist/Loupe-$version.dmg"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

LOUPE_DISTRIBUTION=1 "$root/scripts/bundle.sh" >/dev/null
cp -R "$root/dist/Loupe.app" "$stage/"
ln -s /Applications "$stage/Applications"

rm -f "$dmg"
hdiutil create -volname "Loupe" -srcfolder "$stage" -fs HFS+ -format ULFO -quiet "$dmg"

if [[ -n "${LOUPE_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$LOUPE_SIGNING_IDENTITY" "$dmg"
  if [[ -n "${LOUPE_NOTARY_PROFILE:-}" ]]; then
    keychain=()
    [[ -n "${LOUPE_NOTARY_KEYCHAIN:-}" ]] && keychain=(--keychain "$LOUPE_NOTARY_KEYCHAIN")
    xcrun notarytool submit "$dmg" --keychain-profile "$LOUPE_NOTARY_PROFILE" ${keychain[@]+"${keychain[@]}"} --wait
    xcrun stapler staple "$dmg"
  fi
fi
echo "$dmg"
