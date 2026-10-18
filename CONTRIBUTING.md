# Contributing

Issues and pull requests are welcome. Keep changes focused and run `swift test` before opening a pull request.

## Development

Requires macOS 15 and Xcode 26 (Swift 6.2) or later.

```sh
./scripts/bundle.sh        # builds and signs dist/Loupe.app
open dist/Loupe.app
swift test                 # model, zoom, rendering and app tests
```

Recordings live in `~/Movies/Loupe`. Set `LOUPE_LIBRARY` to point the app at another folder, and seed a demo
recording there with:

```sh
LOUPE_SEED_LIBRARY=/tmp/loupe-demo swift test --filter DemoLibraryTests
LOUPE_LIBRARY=/tmp/loupe-demo dist/Loupe.app/Contents/MacOS/Loupe
```

## Layout

| Path | Contents |
| --- | --- |
| `Sources/LoupeCore/Model` | Project, style and input event types |
| `Sources/LoupeCore/Zoom` | Zoom planning and the spring camera path |
| `Sources/LoupeCore/Rendering` | Core Image frame renderer, custom compositor, audio mixdown and exporter |
| `Sources/Loupe/Capture` | Screen, camera and input capture into a single movie |
| `Sources/Loupe/Overlays` | Setup panel, camera bubble, countdown and recording controls |
| `Sources/Loupe/Library` | Recording storage and the library grid |
| `Sources/Loupe/Editor` | Preview, timeline, inspector and export |
| `assets` | Icon and banner sources and README media |

## Signing

Local builds are ad-hoc signed with a requirement pinned to the bundle identifier, so macOS keeps permission grants
across rebuilds. That requirement trusts any local binary with the same identifier, so keep these builds on your own
Mac.

`LOUPE_DISTRIBUTION=1` builds a universal binary signed per build instead. Setting `LOUPE_SIGNING_IDENTITY` signs with
that certificate, enables the hardened runtime and turns on the updater. `LOUPE_SIGNING_KEYCHAIN` points at the keychain
holding it when that keychain isn't on the search list.

The updater installs a release only when the new app satisfies the running app's designated requirement, which pins
the signing certificate. Releases must therefore always be signed with the same certificate: a stable self-signed one
works, and also keeps permission grants across updates. A Developer ID certificate adds notarization, so the first
launch needs no confirmation.

## Releasing

Push a tag such as `v0.2.0`. The release workflow tests, packages `Loupe-0.2.0.dmg` with `scripts/package.sh`, and
publishes it with checksums to GitHub Releases.

To sign releases, add these repository secrets:

| Secret | Value |
| --- | --- |
| `SIGNING_CERTIFICATE` | Base64 encoded `.p12` with the signing certificate and key |
| `SIGNING_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `NOTARY_APPLE_ID` | Apple ID used for notarization, Developer ID only |
| `NOTARY_TEAM_ID` | Apple Developer team ID, Developer ID only |
| `NOTARY_PASSWORD` | App-specific password for that Apple ID, Developer ID only |

Without a certificate, releases are ad-hoc signed and don't update themselves.
