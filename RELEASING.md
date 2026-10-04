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
gitignored and must never be committed; they are built by the release asset step
and packaged into the gem at build time. The served WebUI is fully offline:
all executable assets ship inside the gem (enforced by tests and the release
check).

Application directories follow XDG on Linux: config under
`~/.config/invasion-studio`, cache under `~/.cache/invasion-studio`, data
under `~/.local/share/invasion-studio`. Project folders own their clips,
database, exports, and trash.

## Release process

1. Run `bin/release version patch|minor|major` or an explicit
   `[v]X.Y.Z[-PRERELEASE]`. This updates Ruby/Electron metadata and Gemfile.lock;
   it does not commit, tag or publish. Update the changelog and commit the source.
2. Run `bin/release` for the desktop artifact and/or `bin/release --gem` for the
   standalone gem. Builds do not run tests. Desktop and gem materials are staged
   separately under `pkg/release/<version>/desktop/` and `gem/`. Each target is
   replaced only after assembly succeeds. Old top-level release files from the
   previous tooling are not part of these new release folders.
3. Explicitly run `bin/test --release` after building the desktop backend. It runs
   the non-video Ruby/frontend/Electron suites, checks a clean checkout, rebuilds
   and validates the gem, installs it into an isolated GEM_HOME, checks its CLI
   and WebUI/assets, then checks the desktop backend using an empty project.
   Network access is needed for npm and gem installation. `ALLOW_DIRTY=1` skips
   the clean-tree requirement for local development only.
4. Run `bin/test --video` and `bin/test --media-package` manually when checking
   media behavior, then complete the acceptance checklist below. These checks
   are deliberately excluded from the default and release test commands.
5. Review license/source completeness, test offline operation, tag the accepted
   source and publish matching artifacts/source materials together. Gem publication
   remains explicit: `gem push invasion-studio-<gem-version>.gem`.

## Linux desktop release

The desktop application is additive: it embeds the same `invasion-studio
webui` command that remains available through the Ruby gem. The first desktop
release targets Linux x64 and Flatpak. Windows x64 and macOS x64/ARM64 have
reserved directories under `desktop/electron/platforms/`, but are not release
targets yet.

Build prerequisites: Ruby/Bundler, Node.js/npm, Python 3, ImageMagick 7, a C
compiler, make, curl, sha256sum, Flatpak, flatpak-builder, and elfutils (`eu-strip`). Install the 26.08 Freedesktop
Platform/SDK and Electron BaseApp from Flathub before building.

For a local rebuild and reinstall, close the app and run `bin/release --install`.
This builds a fresh desktop artifact, assembles its release materials, then
installs the generated Flatpak for the current user. Failure stops installation.
For UI iteration, use `bin/dev`; packaging is unnecessary.

The sidecar uses Ruby from `mise.toml`, the checksummed Tebako 2.8.24 packager,
and the latest published Ruby 4.0.7 Linux GNU x64 runtime (0.16.31). Runtime
0.16.32 currently has no artifact for that combination. Downloads and build
staging are cached in `pkg/tebako/`, and Tebako also caches downloaded runtimes
in its user store (`~/.tebako/` by default). Docker is no longer required.

Dependency checks on 2026-10-03 updated all direct app dependencies to their
latest stable releases. Two transitive Ruby gems retain upstream constraints:
Sinatra 4.2.1 requires Mustermann 3.x, and tty-progressbar 0.18.3 requires
unicode-display_width below 3. Tailwind's watcher is overridden to 2.6.0 to
remove the vulnerable braces dependency. Review these exceptions on updates.
Electron 44's binary installation is explicitly run by the desktop package's
postinstall script.

1. Run `bin/setup` and install the platform prerequisites above.
2. Run `bin/release --install` to rebuild the backend, frontend, icons and Flatpak,
   assemble sources/notices/checksums, and install the result. It does not run tests.
   The desktop-only Gemfile pins runtime dependencies from Gemfile.lock.
3. Run `bin/test --release`, then `bin/test --installed`. The latter checks version,
   local assets, settings/compilation persistence, restart and shutdown inside the
   installed Flatpak using temporary project/settings directories.
4. Launch `flatpak run com.bladeofmaya.InvasionStudio` and complete the manual checks.
5. If distributing the gem too, run `bin/release --gem`. Upload the contents of the
   explicitly selected target folders; desktop assembly never picks up an old gem.
6. Only after acceptance, publish artifacts with matching source snapshots and
   complete license/source materials, including the embedded Ruby/Tebako runtime.
   Signing and automatic updates are not implemented. No command publishes for you.

FFmpeg 9.0.2, Leptonica 1.87.0, Tesseract 5.5.3, and tessdata_fast 4.1.0 are pinned
by URL and SHA-256 in `desktop/flatpak/media-modules.json`. FFmpeg is built without
GPL/nonfree components, with built-in H.264/HEVC decoders and AAC encoding; the
app's normal video editing/export operations copy video streams. Shared system
libraries are supplied by the Freedesktop runtime. Do not substitute its default
FFmpeg: that build may lack required software decoders.

Full media notices live at `/app/share/licenses/`. Electron's notices are beside
its executable; application/frontend and collected backend notices live in
Electron resources. The media-source archive is part of the release, not an
optional download to omit when mirroring the binaries.

The application version in Ruby and Electron package/lockfile must agree; `bin/release version`
updates all of them. `bin/test --packaged` verifies the running backend's version.
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

Default and release checks do not process videos. `bin/test --packaged` verifies startup,
version, local assets, settings/compilation persistence, restart, and shutdown.
Byte-range serving is covered by the dummy-file API tests; playback remains an
owner check. Do not describe an artifact as accepted until this checklist passes.

## Not automated (deliberately)

- Gem-oriented OS packages (Homebrew, pacman) remain future work; they should wrap the
  same `bin/release --gem` entry point.
- There is no CI service configured; `bin/test --release` is the gate. If CI
  is added later, it should run the same script.

## Browser UI and notice checks

Run `bin/test --browser` before accepting a candidate. It builds current assets
and uses the installed Electron Chromium to exercise real Stimulus navigation,
clip-title editing, search/selection restoration, settings, compilation dialog
layout, blob cover preview/upload, theme switching and local-only requests.
It requires a graphical session (or an externally provided virtual display).
Its project/profile are temporary; fixture media serving and processing are disabled.
It does not validate real playback, OCR, cutting or exports.

The 2026-10-04 audit is in `docs/runtime-redistribution-audit.md`. Runtime notices
are now staged separately alongside media sources. That notice archive is not a
complete Ruby/Tebako corresponding-source bundle: the audit's remaining items
must be resolved before publication. Rebuild artifacts before installed checks;
the previous local package does not include the latest changes.
