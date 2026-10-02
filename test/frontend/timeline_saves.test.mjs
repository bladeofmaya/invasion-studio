import test from 'node:test'
import assert from 'node:assert/strict'
import { TimelineSaves } from '../../lib/invasion_studio/webui/frontend/timeline_saves.mjs'

test('saves remain ordered and keep the clip ID captured at edit time', async () => {
  const writes = []
  let release
  const blocked = new Promise(resolve => { release = resolve })
  const queue = new TimelineSaves(async (id, kind, values) => {
    if (!writes.length) await blocked
    writes.push({ id, kind, values })
  })
  const markers = [{ time: 2 }]
  queue.save('first', 'markers', markers)
  markers[0].time = 9
  queue.save('second', 'cuts', [])
  queue.save('first', 'markers', markers)
  release()
  assert.equal(await queue.flush('first'), true)
  assert.deepEqual(writes.map(write => write.id), ['first', 'second', 'first'])
  assert.equal(writes[0].values[0].time, 2)
  assert.equal(writes[2].values[0].time, 9)
})

test('failed saves block finalization until retry succeeds', async () => {
  let fail = true
  const queue = new TimelineSaves(async () => { if (fail) throw Error('Offline') })
  queue.save('clip', 'markers', [{ time: 2 }])
  assert.equal(await queue.flush('clip'), false)
  assert.equal(queue.hasUnsaved, true)
  fail = false
  await queue.retry('clip')
  assert.equal(await queue.flush('clip'), true)
  assert.equal(queue.hasUnsaved, false)
})
