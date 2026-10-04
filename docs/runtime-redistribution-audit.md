# v0.8.0 runtime redistribution audit

Reviewed 2026-10-04 against the local staged Linux x64 backend and installed
frontend/Electron dependencies. This is a technical inventory audit, not a
completed clearance for public distribution. Recheck the next rebuilt artifact.

| Layer | Evidence inspected | Result / next action |
|---|---|---|
| Frontend | `package-lock.json`, installed package manifests and `THIRD_PARTY_LICENSES.md` | Corrected Video.js from 10.0.0-rc.4 to 10.0.1. Stimulus, Lucide, SortableJS and Video.js notices remain included. |
| Electron/Chromium | `desktop/electron/node_modules/electron/dist/LICENSE` and `LICENSES.chromium.html`, Forge resource configuration | Both notice files are present. Release staging now also archives these with backend notices. Verify the packaged copies after rebuilding. |
| Ruby gems | `pkg/sidecar/linux-x64/backend-notices/inventory.json` | 104 entries, all declare licenses. The notices tree has 71 files; this is not one notice per gem. Default gems may rely on Ruby COPYING. Reconcile each entry with its actual license text before publication. |
| Ruby/Tebako | Backend build-info: Ruby 4.0.7, packager 2.8.24, runtime 0.16.31 | Top-level Ruby COPYING/BSDL and Tebako notices exist. These do not establish completeness for compiled dependencies. |
| Runtime provenance | Extracted `__tpkg__/manifest.yaml` and `lib/tebako/layout.yaml` | Runtime manifest identifies source digest `6add73cb149cbaea78687a6bca5cb817f905ed8bedde9b4149cc13456afb7797` and patch set `spec22-chain`, but no complete source URL/component inventory. Collector now preserves these manifests for subsequent builds. |
| Media tools | `desktop/flatpak/media-modules.json` and `script/prepare-release` | Checksummed FFmpeg 9.0.2, Leptonica 1.87.0, Tesseract 5.5.3 and English model 4.1.0 sources are staged with build options. FFmpeg configuration has no GPL/nonfree enable flags. This archive covers media tools only. |
| Flatpak base | Release build-info records Platform/SDK/Electron BaseApp commits | Retain exact refs/commits and identify any copied base components in the final package. These are distinct from the application's media-source archive. |

## Remaining publication blockers

1. Obtain the exact runtime factory source, patches and build recipe corresponding
   to the manifest digest, including Ruby and the filesystem/preload/bootstrap
   components. Record pinned source URLs/checksums and embedded native dependency
   versions, then collect their notices and any required source/relink materials.
   Do not assume historical Tebako/DwarFS dependency lists describe this runtime:
   its layout identifies a TFS preload shim.
2. Reconcile all 104 gem entries against notices, including default gems and native
   extensions (notably the precompiled sqlite3 gem and its SQLite dependency).
3. Inspect the newly built Flatpak, verify its notices against those inventories,
   and publish the matching application source snapshot and dependency materials.
   The existing local candidate predates this work and is not current evidence.

Upstream references: [Tebako architecture and source](https://github.com/tamatebako/tebako)
and [FFmpeg licensing/build checklist](https://ffmpeg.org/legal.html). The latter
explains why build configuration and corresponding sources matter in addition to
copying a license file. No public publication was performed in this pass.
