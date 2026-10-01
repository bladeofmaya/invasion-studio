# Direct audio-track investigation

The manual probe opens an original recording through a file input and a Blob URL.
It uses HTMLMediaElement.audioTracks to select an embedded audio stream. It does
not run the Ruby server, FFmpeg, or a remuxer; no preview file is generated.
Probes are excluded from the production package.

## Findings (2026-10-01)

On Linux, with Electron **43.3.0 / Chromium 150.0.7871.212**:

| Configuration | audioTracks | AudioTrack.enabled setter |
| --- | --- | --- |
| Default web preferences | Absent | Absent |
| enableBlinkFeatures: AudioVideoTracks | AudioTrackList exposed | Present |

No video was loaded for the automated capability check, so its empty track count
is expected. In a subsequent manual test, `clip_00084.mp4` (about 1 GB) exposed
four tracks and loaded metadata in 34 ms. The user confirmed track 4 was audible.
Diagnostics showed switching while paused retained the source and time, followed
by successful playback and seeking. Other codecs and recordings still need
manual validation.

Chromium currently classifies AudioVideoTracks as experimental:
https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/blink/renderer/platform/runtime_enabled_features.json5

The exact Chromium version's FFmpegDemuxer::OnTracksChanged implementation selects
the requested stream, disables the others, and seeks at the current playback time:
https://chromium.googlesource.com/chromium/src/+/150.0.7871.212/media/filters/ffmpeg_demuxer.cc

The probe enables only this specific feature, retaining sandboxing, context
isolation, and web security. Exposing an experimental API does not establish that
it is reliable enough for production.

## Run

From the repository root, after installing desktop dependencies:

```sh
npm run probe:audio-tracks --prefix desktop/electron -- --capabilities
npm run probe:audio-tracks --prefix desktop/electron
```

The first command only checks API exposure in hidden windows. The second opens a
manual player and does nothing with media until you select a file. If the Electron
binary is absent after packaging, restore it with
`node desktop/electron/node_modules/electron/install.js`.
On a Wayland-only session, append `-- --ozone-platform=wayland` to the player command.

## Manual acceptance checklist

1. Select an original multi-track HEVC/AAC recording. Confirm every expected audio
   track appears, including the normally selected fourth track.
2. Play it and listen to every track. Check that the audible source really changes;
   track flags or labels alone are insufficient evidence.
3. Switch while playing and while paused. Confirm time and pause state are preserved.
4. Seek forward and backward after switching; verify audio/video synchronization.
5. Repeat with H.264/AAC and another representative recording. Note time to first
   frame and whether switching is acceptably responsive on the external disk.
6. Copy diagnostics from the text area if playback or switching fails. F12 opens
   Developer Tools. Diagnostics include filenames but not the absolute file path.

The main app now uses the original `/clip/:filename` response without
`audio_track` when the API is available, with a remux fallback for runtimes that
cannot expose/select the requested track. HTTP range serving is covered by a
test using dummy bytes. The probe uses local Blob URLs, so actual playback over
the main app's HTTP path still needs manual validation; the probe does not by
itself resolve the previously observed network errors.
