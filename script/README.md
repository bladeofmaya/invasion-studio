# Internal tooling

Use `bin/setup`, `bin/dev`, `bin/release`, `bin/test` and the application CLI
`bin/invasion-studio`. Scripts here are implementation details, not independent
release workflows. Public launchers activate the pinned mise toolchain and run
from the repository root.

- `dev.mjs` supervises source execution and asset watchers. `environment` handles
  toolchain activation; `console` and `build-icon` support development commands.
- `build-desktop` → `build-sidecar` → `build-assets` packages the desktop app.
  `make-flatpak` keeps Forge temporary files on the build filesystem.
- `build-gem` and `verify-gem` package and validate the standalone Ruby gem.
- `prepare-release` stages only the requested release target, gathers notices and
  pinned media sources, and writes provenance/checksums. It never publishes.
- `bump-version` updates Ruby/Electron version metadata and the Bundler lockfile.
- `release-check` verifies isolated gem installation. `check-desktop` checks an
  empty project using the backend or installed Flatpak.
- `smoke-test-tebako` uses a real sample clip and ffprobe (FFmpeg is stubbed).
  It is exposed only through the explicit `bin/test --media-package` command.

Build commands do not invoke test suites. Tests and media checks are opt-in.
