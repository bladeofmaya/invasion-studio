import assert from 'node:assert/strict'
import test from 'node:test'
import VideoPlayerController from '../../lib/invasion_studio/webui/public/controllers/video_player_controller.js'

test('player retains the settings audio track and reloads an open clip when settings change', () => {
  const controller = {
    clipIdValue: 'clip1', reloads: 0,
    loadClip() { this.reloads++ }
  }
  VideoPlayerController.prototype.applyVideoSettings.call(controller, { audio_track_count: 4, default_audio_track: 2 })
  assert.equal(controller.defaultAudioTrack, 2)
  assert.equal(controller.reloads, 1)
  controller.clipIdValue = ''
  VideoPlayerController.prototype.applyVideoSettings.call(controller, { audio_track_count: 4, default_audio_track: 3 })
  assert.equal(controller.defaultAudioTrack, 3)
  assert.equal(controller.reloads, 1)
})

test('clip loading waits for the configured audio track before starting playback', async () => {
  await VideoPlayerController.prototype.loadClip.call({ defaultAudioTrack: undefined })
})

test('Playback errors are visible and include decoder diagnostics in the console', () => {
  const messages = []
  const original = console.error
  console.error = (...args) => messages.push(args)
  try {
    const controller = { playbackStatusTarget: { hidden: true } }
    VideoPlayerController.prototype.showPlaybackError.call(controller, {
      error: { code: 3, message: 'PIPELINE_ERROR_DECODE' },
      currentSrc: 'http://127.0.0.1:1234/clip/test.mp4', readyState: 1, networkState: 2
    })
    assert.equal(controller.playbackStatusTarget.hidden, false)
    assert.match(controller.playbackStatusTarget.textContent, /decode/i)
    assert.match(messages[0][1], /PIPELINE_ERROR_DECODE/)
    assert.match(messages[0][1], /test.mp4/)
  } finally {
    console.error = original
  }
})

test('finalization waits for timeline saves and refuses failed saves', async () => {
  const timeline = { disabled: false }
  let paused = false
  const controller = {
    clipIdValue: 'first', timeline,
    playback: { video: { pause() { paused = true } } },
    saves: { async flush(id) { assert.equal(id, 'first'); return false } },
    setStatus(message) { this.status = message }
  }
  assert.equal(await VideoPlayerController.prototype.prepareFinalize.call(controller, 'first'), false)
  assert.equal(paused, true)
  assert.equal(timeline.disabled, false)
  assert.match(controller.status, /Retry/)
  controller.saves.flush = async () => true
  assert.equal(await VideoPlayerController.prototype.prepareFinalize.call(controller, 'first'), true)
  assert.equal(timeline.disabled, true)
})

test('selection changing while saving prevents finalizing a different clip', async () => {
  const controller = {
    clipIdValue: 'first', timeline: {}, playback: { video: { pause() {} } },
    saves: { async flush() { controller.clipIdValue = 'second'; return true } }
  }
  assert.equal(await VideoPlayerController.prototype.prepareFinalize.call(controller, 'first'), false)
})
