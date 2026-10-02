# Video.js v10 prototype

The main clip preview now uses Video.js with the editable timeline and persistent
manual markers. Expand **Edit video** below the video to access seek, cuts, and
markers together. Choose **Start cut**, seek forward, then **End cut here** to
mark a removal range; Cancel abandons a pending range. Undo and Finalize appear
when relevant. Add a marker at the playhead, choose its event type, and edit its
optional label or timestamp. Drag markers to move them. Edits save automatically
on change (text labels on blur), and Undo also saves the restored state. Failed
saves display a retry action and block finalization. Finalization removes events
inside removed ranges and shifts the surviving event timestamps.

Automatic OCR event detection recognizes English “Furled Finger … has died” and
“Hunter … has died” messages in the existing invasion-message crop. New imports
save these as Phantom defeated / Hunter defeated markers, with the player name
as the label. Repeated sightings of the same banner are grouped into one event.

Use **Identify markers** in Edit video to rescan an existing clip. This forces a
fresh OCR pass using the project’s extraction settings, displays frame progress,
and merges results with existing markers. Keep the application open while it
runs. Concurrent source-file changes reject the scan results; rerun afterward.
Timing follows the OCR sampling rate and extraction offsets, so markers remain
editable for adjustment. Actual media/OCR accuracy needs manual verification.

The original isolated prototype remains available at `/player-prototype` for
comparison. Its demo events are temporary and do not modify saved manual markers.

Visit `/player-prototype` to open the isolated demo. The player pins
`@videojs/html` to `10.0.0-rc.4` and bundles it locally; no CDN is required.

Select a clip, then choose **Load demo markers + two cuts** to populate the
timeline. Demo events are synthetic, not OCR results. Drag the red range edges,
edit their start/end times, or use Mark start / Mark end at the playhead. Marker
buttons seek to events. Undo restores the previous cut ranges. Disable **Skip
removal ranges during playback** to review the original footage at those times.

Cuts remain drafts until **Save cuts**. Saved cuts appear in the regular player
and survive reopening. Demo markers are temporary and reset when changing clips
or finalizing. **Finalize cuts** confirms, saves, and calls the existing Ruby
finalizer; its stream-copy/keyframe limitations remain unchanged. Loading demo
ranges replaces draft cuts only, and requires confirmation when cuts exist.

The Video.js fullscreen control shows the video skin. **Fullscreen editor**
includes the custom event/cut timeline and editing controls.

## Manual evaluation

- Open a large recording in Electron and select audio track 4. Verify sound,
  seeking, pause/resume, and synchronization before and after changing tracks.
- Repeat in the browser. The existing `ClipPlayback` helper uses original media
  when native audio selection is available and remuxes otherwise.
- Drag both cut boundaries; try keyboard time edits and marker navigation.
- Preview skips, save, return to the regular player, and check the saved cuts.
- Finalize a disposable clip and verify output, cleared cuts, and reloaded media.
- Check both fullscreen modes, narrow windows, and errors for missing media.

Automated checks use timeline calculations, dummy-file API tests, and an Electron
smoke check with mocked media. No real video processing was run by the agent.
The isolated demo keeps its synthetic events temporary; the main editor supports
persistent manual markers and OCR detection as described above.
