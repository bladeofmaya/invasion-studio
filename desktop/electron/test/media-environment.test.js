import assert from 'node:assert/strict'
import test from 'node:test'
import { mediaEnvironment } from '../src/media-environment.js'

test('development preserves the configured system tools', () => {
  const env = { PATH: '/usr/bin', INVASION_STUDIO_FFMPEG: '/custom/ffmpeg' }
  assert.deepEqual(mediaEnvironment(env), env)
})

test('Flatpak uses only the shipped media tools and English data', () => {
  const checked = []
  const env = mediaEnvironment({ FLATPAK_ID: 'com.bladeofmaya.InvasionStudio' }, (file, mode) => checked.push([file, mode]))
  assert.equal(env.INVASION_STUDIO_FFMPEG, '/app/bin/ffmpeg')
  assert.equal(env.INVASION_STUDIO_FFPROBE, '/app/bin/ffprobe')
  assert.equal(env.INVASION_STUDIO_TESSERACT, '/app/bin/tesseract')
  assert.equal(env.TESSDATA_PREFIX, '/app/share/tessdata')
  assert.equal(checked.length, 4)
})

test('incomplete Flatpak fails with a diagnostic instead of host fallback', () => {
  assert.throws(() => mediaEnvironment({ FLATPAK_ID: 'com.bladeofmaya.InvasionStudio' }, () => {
    throw new Error('missing')
  }), /Missing or inaccessible packaged dependency: \/app\/bin\/ffmpeg/)
})

test('desktop backend does not inherit systemd notification or socket activation', () => {
  const inherited = {
    PATH: '/usr/bin', NOTIFY_SOCKET: '/run/user/1000/systemd/notify',
    WATCHDOG_PID: '12', WATCHDOG_USEC: '1000', LISTEN_PID: '12', LISTEN_FDS: '1', LISTEN_FDNAMES: 'http'
  }
  assert.deepEqual(mediaEnvironment(inherited), { PATH: '/usr/bin' })
  assert.ok(inherited.NOTIFY_SOCKET, 'do not mutate the Electron process environment')
})
