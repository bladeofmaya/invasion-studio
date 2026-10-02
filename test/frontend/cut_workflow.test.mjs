import test from 'node:test'
import assert from 'node:assert/strict'
import { ClipTimeline } from '../../lib/invasion_studio/webui/frontend/clip_timeline.mjs'

function timeline() {
  return Object.assign(Object.create(ClipTimeline.prototype), {
    video: { currentTime: 5 }, cuts: [], history: [], startButton: {}, message: {},
    render() {}, onChange() {}
  })
}

test('one control starts and completes a removal range', () => {
  const editor = timeline()
  editor.toggleCut()
  assert.equal(editor.start, 5)
  assert.deepEqual(editor.cuts, [])
  editor.video.currentTime = 12
  editor.toggleCut()
  assert.deepEqual(editor.cuts, [{ start: 5, end: 12 }])
  assert.equal(editor.start, null)
})

test('canceling a pending cut leaves existing cuts untouched', () => {
  const editor = timeline()
  editor.toggleCut()
  editor.cancelCut()
  assert.equal(editor.start, null)
  assert.deepEqual(editor.cuts, [])
  assert.equal(editor.history.length, 0)
})

test('an end before the start keeps the pending selection and explains the next action', () => {
  const editor = timeline()
  editor.toggleCut()
  editor.video.currentTime = 2
  editor.toggleCut()
  assert.equal(editor.start, 5)
  assert.deepEqual(editor.cuts, [])
  assert.match(editor.message.textContent, /forward/)
})

test('timeline seeking uses the full marker scale and clamps to clip boundaries', () => {
  const editor = timeline()
  Object.assign(editor, {
    field: { disabled: false }, video: { duration: 100, currentTime: 0 },
    track: { getBoundingClientRect: () => ({ left: 20, width: 200 }) }, tick() {}
  })
  editor.seekAt(120)
  assert.equal(editor.video.currentTime, 50)
  editor.seekAt(-10)
  assert.equal(editor.video.currentTime, 0)
  editor.seekAt(250)
  assert.equal(editor.video.currentTime, 100)
  editor.field.disabled = true
  editor.seekAt(120)
  assert.equal(editor.video.currentTime, 100)
})

test('timeline keyboard seeking supports arrows and clip boundaries', () => {
  const editor = timeline()
  Object.assign(editor, { field: { disabled: false }, video: { duration: 100, currentTime: 50 }, tick() {} })
  const press = key => editor.seekKey({ key, preventDefault() {} })
  press('ArrowRight')
  assert.equal(editor.video.currentTime, 51)
  press('Home')
  assert.equal(editor.video.currentTime, 0)
  press('End')
  assert.equal(editor.video.currentTime, 100)
})
