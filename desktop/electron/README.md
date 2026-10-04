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

Pinned development dependencies include Electron 44.5.1, Electron Forge
8.0.1, and `@electron/fuses` 2.1.3. The Flatpak maker targets Freedesktop
Platform/SDK and Electron BaseApp 26.08.

## Security boundary

Both renderers have Node integration disabled, context isolation and Chromium's
sandbox enabled, denied permission requests, and restricted navigation. The
launcher has a minimal preload bridge limited to listing recent projects and
requesting validated native folder selection. The Sinatra WebUI window exposes only validated recording selection and
project-folder opening through its preload bridge. HTTPS links may open in the system browser. Packaging disables
RunAsNode and Node CLI environment fuses and requires an integrity-checked ASAR.

## Develop, package and test

From the repository root:

```sh
bin/setup
bin/dev /path/to/project       # Source Ruby + watched frontend; no packaging
bin/dev --browser /path/to/project
bin/test                      # Non-video suites
bin/release                   # Build Linux x64 Flatpak and release materials
bin/release --install          # Build and reinstall
bin/test --packaged            # Check the built backend with an empty project
bin/test --installed           # Check the installed Flatpak with an empty project
```

Development uses a separate Electron user-data directory and source Ruby.
Templates/assets reload automatically; Ruby and Electron source changes restart
the development window. No tests run implicitly. See the root README for console,
icon, version and standalone-gem commands.

Releases always rebuild the backend before packaging. Forge output lives under
`desktop/electron/out/`, the backend under `pkg/sidecar/linux-x64/`, and assembled
release materials under `pkg/release/<version>/desktop/`. The Flatpak builds pinned
media tools from `../flatpak/media-modules.json` and includes English OCR data.
Media notices live in `/app/share/licenses`; other notices live in Electron
resources. `script/make-flatpak` handles the same-filesystem temporary-directory
requirement internally.

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
