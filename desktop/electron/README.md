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

Both renderers have Node integration disabled, context isolation and Chromium's
sandbox enabled, denied permission requests, and restricted navigation. The
launcher has a minimal preload bridge limited to listing recent projects and
requesting validated native folder selection. The Sinatra WebUI window exposes only validated recording selection and
project-folder opening through its preload bridge. HTTPS links may open in the system browser. Packaging disables
RunAsNode and Node CLI environment fuses and requires an integrity-checked ASAR.

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

# Open the project launcher.
bin/run-desktop

# Or bypass the launcher during development.
bin/run-desktop /path/to/project

# Run Forge's Flatpak maker.
bin/build-desktop --make
```

Both desktop builds recreate the sidecar to prevent application/database
migrations from becoming newer than the packaged backend. The unpacked app is
written to `desktop/electron/out/InvasionStudio-linux-x64`; Forge writes
installers under `desktop/electron/out/make`. The sidecar is written to
`pkg/sidecar/linux-x64/invasion-studio`. The unpacked app uses host media tools and is for development.
The release Flatpak builds FFmpeg, Leptonica, and Tesseract from checksummed
sources in `../flatpak/media-modules.json`, installs English trained data, and
uses `/app/bin` executables. Missing packaged tools stop startup with a diagnostic.
License texts are installed in `/app/share/licenses` and Electron resources.

`bin/make-flatpak` keeps temporary build files and the Flatpak cache on the same
filesystem. For a shell-only change after building the backend, use
`npm run make --prefix desktop/electron`; `bin/build-desktop --make` rebuilds all.

Run `bin/check-desktop` for an empty-project backend check, or
`bin/check-desktop --flatpak` after installing the Flatpak. Both check version,
local assets, settings/compilation persistence, restart, and shutdown. Neither
processes videos. The latter uses a temporary project and temporary settings.

Recent projects are stored in Electron's per-user application-data directory.
Missing folders are pruned when the launcher loads. The list contains only
folder paths and last-opened timestamps; project content and `project.db` stay
inside each selected project.

## Manual release checks

Project instructions prohibit automated tests that process video. Manually
verify the packaged application using a representative 2K, five-audio-track
clip:

- upload, metadata, H.264/AAC playback, seeking, and pause/resume;
- settings-selected audio track, read-only player label, and audible result;
- reopen a clip after changing the default track in Settings;
- original playback without new `.preview_cache` files when supported;
- remux fallback in a browser without direct audio-track support;
- project persistence and arbitrary project-folder access under Flatpak;
- window close, sidecar exit, cold start, readiness latency, and RSS.

### Playback diagnostics

The desktop player enables Chromium's experimental `AudioVideoTracks` feature
and selects audio directly in the original video, avoiding preview-cache copies.
Players without this API, or unable to select the requested track, use the
existing FFmpeg remux fallback. Track numbers are one-based and the configured
default track is applied after metadata loads. Console messages identify direct
versus remux playback. The retired standalone probe and isolated player demo
are no longer shipped.

The desktop shell writes a rotating `desktop.log` (plus `desktop.log.1`) under
Electron's application logs directory. The exact path is printed at startup.
It includes backend stdout/stderr, renderer console messages, and video request
results. Press **F12** in the main window to open Developer Tools; the Console
shows `Preview playback failed` with the browser's media error code and message.
The player also displays loading and failure messages. Logs may include local
project/video paths, so review them before sharing.
