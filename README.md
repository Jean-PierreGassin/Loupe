# Loupe

A free, local screen recorder for macOS. Record your screen, voice and webcam, and Loupe automatically zooms in on
every click and typing burst. Exports polished MP4s with a styled background, rounded frame and camera bubble.

## Features

- Screen, system audio and microphone capture with ScreenCaptureKit
- Draggable live webcam bubble in three sizes, composited at export so it stays editable
- Auto zoom planned from clicks and typing, with a spring-driven camera that follows the pointer
- Timeline editor: trim, add, move, resize and retune zooms, drag the camera bubble on the preview
- Backgrounds, padding, roundness, shadow and click highlights
- 1080p, 1440p and 4K export with one-click copy for pasting into chat apps
- Global shortcut ⌥⇧⌘R to start and stop

Keystrokes are only timestamped to plan zooms. Loupe never records which keys you press.

## Build

Requires macOS 15 or later to run, and Xcode 26 (Swift 6.2) or later to build.

```sh
./scripts/bundle.sh        # builds dist/Loupe.app
open dist/Loupe.app
swift test                 # model, zoom planner and render pipeline tests
```

The first recording asks for Screen Recording, Camera and Microphone access. Accessibility access is optional and
enables typing zooms that follow the text caret.

Recordings live in `~/Movies/Loupe`, exports in `~/Movies/Loupe/Exports`. Set `LOUPE_LIBRARY` to use another folder.

### Signing

By default `bundle.sh` ad-hoc signs the app with a requirement pinned to its bundle identifier, so macOS keeps your
permission grants across rebuilds. That requirement trusts any local binary with the same identifier, so only use
these builds on your own Mac.

To sign for distribution, set a Developer ID identity. The app is then signed with the hardened runtime and the
camera and microphone entitlements, ready for notarization:

```sh
LOUPE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/bundle.sh
```

## Layout

| Path | Contents |
| --- | --- |
| `Sources/LoupeCore/Model` | Project, style and input event types |
| `Sources/LoupeCore/Zoom` | Zoom planning and the spring camera path |
| `Sources/LoupeCore/Rendering` | Core Image frame renderer, custom compositor and exporter |
| `Sources/Loupe/Capture` | Screen, camera and input capture into a single movie |
| `Sources/Loupe/Overlays` | Setup panel, camera bubble, countdown and recording controls |
| `Sources/Loupe/Library` | Recording storage and the library grid |
| `Sources/Loupe/Editor` | Preview, timeline, inspector and export |

## Contributing

Issues and pull requests are welcome. Run `swift test` before opening a pull request.

## License

[MIT](LICENSE)
