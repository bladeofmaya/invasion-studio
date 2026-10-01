import assert from 'node:assert/strict'
import test from 'node:test'
import { ClipPlayback } from '../../lib/invasion_studio/webui/frontend/clip_playback.mjs'

class FakeVideo extends EventTarget {
  constructor(direct = true) {
    super()
    if (direct) this.audioTracks = []
    this.src = ''; this.currentTime = 0; this.paused = true; this.readyState = 0
    this.loads = 0; this.plays = 0; this.muted = false
  }
  load() { this.loads++; this.readyState = 0; this.currentTime = 0; this.paused = true }
  play() { this.plays++; this.paused = false; return Promise.resolve() }
  pause() { this.paused = true }
  removeAttribute(name) { if (name === 'src') this.src = '' }
  metadata(count = 4) {
    if ('audioTracks' in this) this.audioTracks = Array.from({ length: count }, (_, i) => ({ enabled: i === 0 }))
    this.readyState = 1
    this.dispatchEvent(new Event('loadedmetadata'))
  }
}

test('capable player requests original HTTP file and selects default track after metadata', () => {
  const video = new FakeVideo()
  const player = new ClipPlayback(video)
  player.load('/clip/clip.mp4', { track: 4 })
  assert.equal(video.src, '/clip/clip.mp4')
  video.metadata()
  assert.deepEqual(video.audioTracks.map(t => t.enabled), [false, false, false, true])
  assert.equal(video.loads, 1)
})

test('direct switching keeps source, time and play state without reload', () => {
  for (const paused of [true, false]) {
    const video = new FakeVideo()
    const player = new ClipPlayback(video)
    player.load('/clip/a.mp4', { track: 1 })
    video.metadata()
    video.currentTime = 94.5; video.paused = paused
    player.selectTrack(4)
    assert.equal(video.src, '/clip/a.mp4')
    assert.equal(video.currentTime, 94.5)
    assert.equal(video.paused, paused)
    assert.equal(video.loads, 1)
    assert.equal(video.audioTracks[3].enabled, true)
  }
})

test('selection while metadata is pending applies the latest track without reloading', () => {
  const video = new FakeVideo()
  const player = new ClipPlayback(video)
  player.load('/clip/a.mp4', { track: 1 })
  player.selectTrack(3)
  video.metadata()
  assert.equal(video.audioTracks[2].enabled, true)
  assert.equal(video.loads, 1)
})

test('unsupported browser uses remux and preserves time and playback when switching', () => {
  const video = new FakeVideo(false)
  const player = new ClipPlayback(video)
  player.load('/clip/a.mp4', { track: 4 })
  assert.equal(video.src, '/clip/a.mp4?audio_track=4')
  video.metadata(); video.currentTime = 35; video.paused = false
  player.selectTrack(2)
  video.metadata()
  assert.equal(video.src, '/clip/a.mp4?audio_track=2')
  assert.equal(video.currentTime, 35)
  assert.equal(video.paused, false)
})

test('missing embedded track falls back once and never selects tracks in a remux', () => {
  const video = new FakeVideo()
  const player = new ClipPlayback(video)
  player.load('/clip/a.mp4', { track: 4 })
  video.metadata(1)
  assert.equal(video.src, '/clip/a.mp4?audio_track=4')
  video.metadata(1)
  assert.equal(video.loads, 2)
})

test('a player that exposes tracks but ignores selection falls back preserving position', () => {
  const video = new FakeVideo()
  const player = new ClipPlayback(video)
  player.load('/clip/a.mp4')
  video.metadata()
  video.currentTime = 42
  video.paused = false
  Object.defineProperty(video.audioTracks[3], 'enabled', { get: () => false, set: () => {} })
  player.selectTrack(4)
  assert.equal(video.src, '/clip/a.mp4?audio_track=4')
  video.metadata(1)
  assert.equal(video.currentTime, 42)
  assert.equal(video.paused, false)
})

test('rapid remux selections retain the original playback position until metadata arrives', () => {
  const video = new FakeVideo(false)
  const player = new ClipPlayback(video)
  player.load('/clip/a.mp4')
  video.metadata()
  video.currentTime = 42
  video.paused = false
  player.selectTrack(2)
  player.selectTrack(3)
  video.metadata()
  assert.equal(video.src, '/clip/a.mp4?audio_track=3')
  assert.equal(video.currentTime, 42)
  assert.equal(video.paused, false)
  assert.equal(video.plays, 1)
})

test('new clip cancels pending restoration and finalization adds a version without remux', () => {
  const video = new FakeVideo(false)
  const player = new ClipPlayback(video)
  player.load('/clip/a.mp4'); video.metadata(); video.currentTime = 80; video.paused = false
  player.selectTrack(2)
  player.load('/clip/b.mp4', { track: 1, version: 'changed' })
  video.metadata()
  assert.equal(video.currentTime, 0)
  assert.equal(video.paused, true)
  const direct = new FakeVideo()
  new ClipPlayback(direct).load('/clip/a.mp4', { track: 4, version: 'changed' })
  assert.equal(direct.src, '/clip/a.mp4?version=changed')
})

test('stop releases media and ignores late events', () => {
  const video = new FakeVideo()
  let calls = 0
  const player = new ClipPlayback(video, { onMetadata: () => calls++ })
  player.load('/clip/a.mp4')
  player.stop()
  video.metadata()
  assert.equal(video.src, '')
  assert.equal(calls, 0)
})
