import assert from 'node:assert/strict'
import test from 'node:test'
import { selectAudioTrack, describeAudioTracks } from '../probes/audio-tracks/selection.js'

test('selects one embedded track without changing the source, time, or pause state', () => {
  const video = {
    src: 'blob:original-recording', currentTime: 42.5, paused: false,
    audioTracks: [
      { id: '1', label: 'Game', language: '', enabled: true },
      { id: '2', label: 'Microphone', language: 'eng', enabled: false }
    ],
    load() { assert.fail('switching must not reload the file') },
    play() { assert.fail('switching must not restart playback') },
    pause() { assert.fail('switching must not pause playback') }
  }
  selectAudioTrack(video, 1)
  assert.deepEqual(video.audioTracks.map(track => track.enabled), [false, true])
  assert.equal(video.src, 'blob:original-recording')
  assert.equal(video.currentTime, 42.5)
  assert.equal(video.paused, false)
  assert.deepEqual(describeAudioTracks(video)[1], { index: 1, id: '2', label: 'Microphone', language: 'eng', enabled: true })
})

test('invalid or unavailable tracks leave selection unchanged', () => {
  assert.throws(() => selectAudioTrack({}, 0), /unavailable/)
  const video = { audioTracks: [{ enabled: true }] }
  for (const index of [-1, 1, 0.5, NaN]) {
    assert.throws(() => selectAudioTrack(video, index), /unavailable/)
    assert.equal(video.audioTracks[0].enabled, true)
  }
})
