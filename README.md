# Steam Front (unofficial)

A lightweight, fully native front-end for your local Steam library.
Built with Flutter — no WebView, no Chromium.

The official Steam client stays in charge of authentication, downloads
and DRM in the background. Steam Front only reads the local library
files and asks the client core to launch games.

## Features

- Library grid with capsule artwork (loaded from the Steam CDN)
- Reads `libraryfolders.vdf` and `appmanifest_*.acf` directly —
  multiple library folders supported
- Install state, size on disk, and download progress per game
- Search and sorting (name / size / recently updated)
- Launch via `steam.exe -applaunch` (Windows) or `steam://rungameid`
- Install requests via `steam://install`

## Build

```sh
flutter pub get
flutter build windows --release   # Windows
flutter build linux --release     # Linux
```

GitHub Actions runs analyze + tests and both platform builds on every
push; pushing a tag like `v0.1.0` publishes a Release with binaries.

## Notes

- Unofficial project, not affiliated with Valve.
- First sign-in and Steam Guard prompts still happen in the official
  client UI; after that the client core can stay in the background
  (for example with the webhelper disabled / Steam started minimized).
- Store purchases and chat are out of scope by design.

## License

MIT
