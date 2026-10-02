# Video editor

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
as the label. The marker is placed eight seconds before the first detected death
banner, clamped to the clip start, to account for the game's delayed message.
This estimates the animation time; banner-delay variation and OCR sampling mean
it is not frame-exact. Repeated sightings of the same banner are grouped into one event.
The offset applies to newly detected markers during import and Identify markers.
Previously saved markers retain their positions (including manual adjustments);
repeat scans do not automatically retime or duplicate them.

Use **Identify markers** in Edit video to rescan an existing clip. This forces a
fresh OCR pass using the project’s extraction settings, displays frame progress,
and merges results with existing markers. Keep the application open while it
runs. Concurrent source-file changes reject the scan results; rerun afterward.
Timing follows the OCR sampling rate and extraction offsets, so markers remain
editable for adjustment. Actual media/OCR accuracy needs manual verification.

The Video.js fullscreen control shows the video skin. **Fullscreen editor**
includes the custom event/cut timeline and editing controls.

## Manual evaluation

- Set audio track 4 in Settings and open a large recording in Electron. Verify
  the player's read-only audio label, sound, seeking, pause/resume, and synchronization.
- Repeat in the browser. The existing `ClipPlayback` helper uses original media
  when native audio selection is available and remuxes otherwise.
- Drag both cut boundaries; try keyboard time edits and marker navigation.
- Preview skips, save, return to the regular player, and check the saved cuts.
- Finalize a disposable clip and verify output, cleared cuts, and reloaded media.
- Check both fullscreen modes, narrow windows, and errors for missing media.

Automated checks use timeline calculations, dummy-file API tests, and an Electron
smoke check with mocked media. No real video processing was run by the agent.
