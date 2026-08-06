# Invasion Studio desktop application

This directory contains the production Electron shell. Electron supervises a
Tebako-packaged `invasion-studio webui` sidecar and displays the real Sinatra
and Stimulus application from its ephemeral loopback origin. The Ruby gem and
standalone browser workflow do not depend on Electron.

## Supported platform

The first desktop release targets Linux x64 with Flatpak as its primary
installer. `platforms/windows-x64`, `platforms/macos-x64`, and
`platforms/macos-arm64` reserve the intended future build matrix without
claiming those targets are implemented.

Pinned development dependencies include Electron 43.3.0, Electron Forge
7.11.2, and `@electron/fuses` 1.8.0. The Flatpak maker targets Freedesktop
Platform/SDK and Electron BaseApp 25.08.

## Security boundary

The renderer has Node integration disabled, context isolation and Chromium's
sandbox enabled, no preload bridge, denied permission requests, and navigation
restricted to the exact sidecar origin. HTTPS links may open in the system
browser. Packaging disables RunAsNode and Node CLI environment fuses and
requires an integrity-checked ASAR.

## Develop and test

From the repository root:

```sh
npm ci --prefix desktop/electron
npm test --prefix desktop/electron

# Build the current Linux sidecar, then launch Electron through Forge.
bin/build-sidecar
INVASION_STUDIO_PROJECT=/path/to/project npm start --prefix desktop/electron
```

The Electron tests use a fake Node sidecar and do not process video.

## Package and run

```sh
# Produce an unpacked Linux application.
bin/build-desktop
bin/run-desktop /path/to/project

# Run Forge's Flatpak maker.
bin/build-desktop --make
```

Both desktop builds recreate the sidecar to prevent application/database
migrations from becoming newer than the packaged backend. The unpacked app is
written to `desktop/electron/out/InvasionStudio-linux-x64`; Forge writes
installers under `desktop/electron/out/make`. The sidecar is written to
`pkg/sidecar/linux-x64/invasion-studio`. Optional
portable tools may be staged under `pkg/tools/linux-x64`; when present, Forge
copies that directory into the application's `resources/tools` directory.
FFmpeg, FFprobe, Tesseract, and `eng.traineddata` still need a pinned download,
checksum, and licensing pipeline before the Flatpak release is self-contained.

## Manual release checks

Project instructions prohibit automated tests that process video. Manually
verify the packaged application using a representative 2K, five-audio-track
clip:

- upload, metadata, H.264/AAC playback, seeking, and pause/resume;
- every FFmpeg-remuxed audio selection and audible track result;
- playback position and state restoration after switching;
- first and cached switch latency and `.preview_cache` growth;
- project persistence and arbitrary project-folder access under Flatpak;
- window close, sidecar exit, cold start, readiness latency, and RSS.

The previous host package was approximately 370 MB including its 60 MB
sidecar. The Flatpak maker has not completed its final distributable stage yet;
that is the next packaging gate.
