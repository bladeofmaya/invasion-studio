# Changelog

## 0.8.0

- Linux x64 Electron desktop application with project creation/opening and recent projects.
- Flatpak packaging with the Ruby backend, FFmpeg/ffprobe, Tesseract and English OCR data.
- In-app extraction with progress and duplicate-recording detection.
- Video.js playback, editable cut timeline, and persistent manual/OCR markers.
- Audio playback follows Settings; the player shows the selected track as a label.
- Phantom/hunter death markers estimate death eight seconds before the detected banner.
- Compilation descriptions and archiving, library search, tags and statistics.
- Dependency diagnostics and separate project-preview/global-OCR cache controls.
- Removed the isolated player prototype and standalone audio-track probe.

The Linux package is a local release candidate until the real-media and clean-machine
acceptance checks in RELEASING.md pass. Windows/macOS installers, signing, automatic
updates, and public publication are not included. The embedded Tebako/DwarFS runtime's
corresponding source materials must be reviewed before public redistribution.
