import assert from 'node:assert/strict'
import test from 'node:test'
import { selectRecordings } from '../src/recording-selection.js'

function fixture() {
  const frame = { url: 'http://127.0.0.1:4321/import' }
  const window = { webContents: { mainFrame: frame } }
  const event = { sender: window.webContents, senderFrame: frame }
  return { event, window }
}

test('recording picker allows multiple videos and returns deterministic order', async () => {
  const { event, window } = fixture()
  const dialog = { showOpenDialog: async (parent, options) => {
    assert.equal(parent, window)
    assert.deepEqual(options.properties, ['openFile', 'multiSelections'])
    return { canceled: false, filePaths: ['/recording-002.mp4', '/recording-001.mp4'] }
  } }
  assert.deepEqual(await selectRecordings(event, window, 4321, dialog), ['/recording-001.mp4', '/recording-002.mp4'])
})

test('recording picker rejects other windows, frames, and origins', async () => {
  const { event, window } = fixture()
  const dialog = { showOpenDialog: () => assert.fail('must not open') }
  await assert.rejects(selectRecordings({ ...event, sender: {} }, window, 4321, dialog))
  await assert.rejects(selectRecordings({ ...event, senderFrame: {} }, window, 4321, dialog))
  window.webContents.mainFrame.url = 'https://example.org'
  await assert.rejects(selectRecordings(event, window, 4321, dialog))
})

test('canceling recording selection leaves the current selection untouched', async () => {
  const { event, window } = fixture()
  assert.equal(await selectRecordings(event, window, 4321, {
    showOpenDialog: async () => ({ canceled: true, filePaths: [] })
  }), null)
})
