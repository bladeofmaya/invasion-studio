# Changelog

## 0.8.0

- Consolidate public tooling into `bin/setup`, `bin/dev`, `bin/release`, `bin/test`
  and `bin/invasion-studio`; move private helpers under `script/`.
- Add source-based Electron/browser development with asset watching, UI reload
  and backend restart, without packaging or automatic tests.
- Separate desktop/gem release assembly and opt-in installation; make media tests
  explicit and include Ruby/frontend/Electron suites in the default test command.

- Updated to Ruby 4.0.7, Node.js 26, Electron 44, Forge 8, stable Video.js 10,
  Flatpak 26.08, FFmpeg 9, and current application dependencies.
- Linux x64 Electron desktop application with project creation/opening and recent projects.
- Flatpak packaging with the Ruby backend, FFmpeg/ffprobe, Tesseract and English OCR data.
- In-app extraction with progress and duplicate-recording detection.
- Video.js playback, editable cut timeline, and persistent manual/OCR markers.
- Compact single-card clip editor with header metadata, an aligned scrubber,
  and permanently visible cut/marker controls.
- Audio playback follows Settings; the player shows the selected track as a label.
- Phantom/hunter death markers estimate death eight seconds before the detected banner.
- Compilation descriptions and archiving, library search, tags and statistics.
- Dependency diagnostics and separate project-preview/global-OCR cache controls.
- Removed the isolated player prototype and standalone audio-track probe.

The Linux package is a local release candidate until the real-media and clean-machine
acceptance checks in RELEASING.md pass. Windows/macOS installers, signing, automatic
updates, and public publication are not included. The embedded Tebako/DwarFS runtime's
corresponding source materials must be reviewed before public redistribution.
