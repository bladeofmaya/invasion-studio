import test from 'node:test'
import assert from 'node:assert/strict'
import { moveBoundary, skipCut } from '../../lib/invasion_studio/webui/frontend/timeline_math.mjs'

test('dragging clamps boundaries to the video and prevents inverted cuts', () => {
  const cuts = [{ start: 2, end: 5 }]
  assert.deepEqual(moveBoundary(cuts, 0, 'start', -5, 10), [{ start: 0, end: 5 }])
  assert.deepEqual(moveBoundary(cuts, 0, 'end', 15, 10), [{ start: 2, end: 10 }])
  assert.equal(moveBoundary(cuts, 0, 'start', 7, 10)[0].start, 4.9)
  assert.deepEqual(cuts, [{ start: 2, end: 5 }])
})

test('preview skips overlapping removal ranges in any order', () => {
  const cuts = [{ start: 4, end: 8 }, { start: 2, end: 6 }]
  assert.equal(skipCut(3, cuts), 8)
  assert.equal(skipCut(8, cuts), 8)
  assert.equal(skipCut(1, cuts), 1)
})

