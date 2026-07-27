# Releasing Invasion Studio

## Dependency matrix

| Kind | Dependency | Needed at |
|------|-----------|-----------|
| Ruby gems | sinatra, puma, sequel, sqlite3, sucker_punch, tty-progressbar, optparse | Runtime (declared in the gemspec, installed by `gem install`) |
| System packages | ffmpeg | Runtime (extraction, thumbnails, preview remux, concat/export) |
| System packages | tesseract | Runtime (extraction/scan OCR only; the WebUI works without it) |
| System packages | kdenlive | Optional (only to open exported `.kdenlive` projects) |
| Build-only | Node.js + npm (Tailwind CLI, esbuild, pinned in package-lock.json) | Building a release from source; never at `gem install` or runtime |
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
   `X.Y.Z`). It updates `lib/invasion_studio/version.rb` and refreshes
   `Gemfile.lock`. Update the changelog/plan docs alongside.
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

## Not automated (deliberately)

- OS packages (Homebrew, pacman) remain future work; they should wrap the
  same `bin/build-gem` entry point.
- There is no CI service configured; `bin/release-check` is the gate. If CI
  is added later, it should run the same script.
