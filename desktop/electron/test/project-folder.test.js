import assert from 'node:assert/strict'
import test from 'node:test'
import { openProjectFolder } from '../src/project-folder.js'

test('opens only the selected project from the trusted main frame', async () => {
  const frame = { url: 'http://127.0.0.1:4321/clips' }
  const window = { webContents: { mainFrame: frame } }
  const event = { sender: window.webContents, senderFrame: frame }
  const opened = []
  const shell = { openPath: async path => { opened.push(path); return '' } }
  await openProjectFolder(event, window, 4321, '/project folder', shell)
  assert.deepEqual(opened, ['/project folder'])
  await assert.rejects(openProjectFolder({ ...event, sender: {} }, window, 4321, '/project', shell))
  await assert.rejects(openProjectFolder({ ...event, senderFrame: {} }, window, 4321, '/project', shell))
  frame.url = 'https://example.org'
  await assert.rejects(openProjectFolder(event, window, 4321, '/project', shell))
  assert.equal(opened.length, 1)
  frame.url = 'http://127.0.0.1:4321/clips'
  await assert.rejects(openProjectFolder(event, window, 4321, '/project', { openPath: async () => 'Unavailable' }), /Unavailable/)
})
