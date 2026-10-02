# Releasing Invasion Studio

## Dependency matrix

| Kind | Dependency | Needed at |
|------|-----------|-----------|
| Ruby gems | sinatra, puma, sequel, sqlite3, sucker_punch, tty-progressbar, optparse | Runtime (declared in the gemspec, installed by `gem install`) |
| System packages | ffmpeg | Runtime (extraction, thumbnails, preview remux, concat/export) |
| System packages | tesseract | Runtime (extraction/scan OCR only; the WebUI works without it) |
| System packages | kdenlive | Optional (only to open exported `.kdenlive` projects) |
| Build-only | Node.js + npm (Tailwind CLI, esbuild, pinned in package-lock.json) | Building a release from source; never at `gem install` or runtime |
| Desktop build | Electron, Electron Forge, and Tebako | Building the Linux desktop application only |
| Build-only | Ruby 3.3.3+, Bundler, a C toolchain | Building; the C toolchain is also needed by `gem install` for the sqlite3/puma native extensions |

Generated frontend assets (`lib/invasion_studio/webui/public/assets/`) are
gitignored and must never be committed; they are built by `bin/build-assets`
and packaged into the gem at build time. The served WebUI is fully offline:
all executable assets ship inside the gem (enforced by tests and the release
check).

Application directories follow XDG on Linux: config under
`~/.config/invasion-studio`, cache under `~/.cache/invasion-studio`, data
under `~/.local/share/invasion-studio`. Project folders own their clips,
database, exports, and trash.

## Release process

1. Bump the version with `bin/bump-version patch|minor|major` (or an explicit
   `[v]X.Y.Z[-PRERELEASE]`, such as `v0.8.0-dev`). The optional input `v` is
   removed from stored metadata and added back for tags/display. It updates
   the Ruby and Electron versions and refreshes `Gemfile.lock`. Update the
   changelog/plan docs alongside.
2. Run `bin/release-check` from a clean checkout. It performs, in order:
   - clean-tree check and a guard that no generated assets are committed
   - `bin/build-assets` (npm ci + Tailwind + esbuild)
   - the non-video test suite (`rake test`)
   - `gem build` + `bin/verify-gem` (packaged executable, views, assets, licenses)
   - `gem install` into an empty temporary `GEM_HOME`
   - CLI smoke test (`--version`) against the installed gem
   - WebUI smoke test: boots `webui` from the installed gem on an empty
     project, asserts the shell renders, packaged CSS/JS are served, and no
     remote executable assets are referenced
   It needs network access (npm and dependency install). `ALLOW_DIRTY=1`
   skips the clean-tree gate during development; never for a real release.
3. Video-processing behavior (extraction, export) is owner-tested manually:
   `rake test:system` plus a manual pass with real recordings.
4. Manually verify the WebUI once with outbound networking disabled (deep
   links, editing, compilations, preview) per TODO.md.
5. Tag and push, then `gem push invasion-studio-<version>.gem`.

## Linux desktop release

The desktop application is additive: it embeds the same `invasion-studio
webui` command that remains available through the Ruby gem. The first desktop
release targets Linux x64 and Flatpak. Windows x64 and macOS x64/ARM64 have
reserved directories under `desktop/electron/platforms/`, but are not release
targets yet.

Build prerequisites: Ruby/Bundler, Node.js/npm, Docker, Flatpak,
flatpak-builder, and elfutils (`eu-strip`). Install the 25.08 Freedesktop
Platform/SDK and Electron BaseApp from Flathub before building.

For a local rebuild and reinstall in one command, close the app and run
`bin/install-desktop`. This runs `bin/build-desktop --make`, then installs the
generated Flatpak for the current user; a failed build stops installation.

1. Run `bin/release-check` (or `ALLOW_DIRTY=1 bin/release-check` while reviewing
   uncommitted changes). `rake test` contains no video-processing tests; the
   Kdenlive integration test lives under `test/system`.
2. Run `bin/build-desktop --make`. This rebuilds local assets and the Tebako
   backend, runs Electron tests, packages the shell, and builds the Flatpak.
   The desktop-only gemspec pins the entire runtime dependency closure from
   Gemfile.lock; it does not change the standalone gem's dependency policy.
3. Run `bin/check-desktop` for empty-project backend checks.
4. Install the generated Flatpak:
   `flatpak install --user desktop/electron/out/make/flatpak/x86_64/com.bladeofmaya.InvasionStudio_stable_x86_64.flatpak`.
5. Run `bin/check-desktop --flatpak`. Verify the installed app with
   `flatpak run com.bladeofmaya.InvasionStudio` and complete the manual checks below.
6. Build the gem with `bin/build-gem` if not already produced by the release gate.
7. Run `bin/prepare-release` to assemble the versioned Flatpak, gem, media source
   archives, notices, dependency/build inventories, and SHA256SUMS under
   `pkg/release/0.8.0/`. This command downloads and verifies pinned sources;
   it does not publish anything.
8. Only after acceptance: commit the reviewed source, attach the corresponding
   source snapshot, verify license/source completeness (including the embedded
   Ruby/Tebako runtime), and publish artifacts and matching source materials
   together. Signing and automatic updates are not implemented.

FFmpeg 7.1.3, Leptonica 1.86.0, Tesseract 5.5.1, and tessdata_fast 4.1.0 are pinned
by URL and SHA-256 in `desktop/flatpak/media-modules.json`. FFmpeg is built without
GPL/nonfree components, with built-in H.264/HEVC decoders and AAC encoding; the
app's normal video editing/export operations copy video streams. Shared system
libraries are supplied by the Freedesktop runtime. Do not substitute its default
FFmpeg: that build may lack required software decoders.

Full media notices live at `/app/share/licenses/`. Electron's notices are beside
its executable; application/frontend and collected backend notices live in
Electron resources. The media-source archive is part of the release, not an
optional download to omit when mirroring the binaries.

The Ruby version and Electron package/lockfile must agree; `bin/bump-version`
updates all of them. `bin/check-desktop` verifies the running backend's version.
Runtime branches receive security updates, so `build-info.json` records the
installed Flatpak commits. Byte-for-byte reproducibility is not claimed.

### Owner acceptance checklist (real media)

- [ ] Install on a clean Linux x64 machine with no host Ruby/media tools.
- [ ] Create/open projects in home and on an external drive; reopen from Recents.
- [ ] Verify offline UI, import, metadata/thumbnails, searching, tags and compilations.
- [ ] Play representative H.264/AAC recordings, seek/scrub and jump to markers.
- [ ] Change the default audio track in Settings, reopen the clip, and verify its label and sound.
- [ ] Extract invasions; verify progress, duplicate-import protection and death-marker timing.
- [ ] Trim/finalize a disposable clip, export a compilation, and open the Kdenlive output.
- [ ] Close during idle and after processing; confirm no backend remains running.
- [ ] Back up an existing project, upgrade, and verify saved metadata/cuts/markers.

Automated checks do not process videos. `bin/check-desktop` verifies startup,
version, local assets, settings/compilation persistence, restart, and shutdown.
Byte-range serving is covered by the dummy-file API tests; playback remains an
owner check. Do not describe an artifact as accepted until this checklist passes.

## Not automated (deliberately)

- Gem-oriented OS packages (Homebrew, pacman) remain future work; they should wrap the
  same `bin/build-gem` entry point.
- There is no CI service configured; `bin/release-check` is the gate. If CI
  is added later, it should run the same script.
