import assert from 'node:assert/strict'
import test from 'node:test'
import SettingsController from '../../lib/invasion_studio/webui/public/controllers/settings_controller.js'

test('project location is escaped, selectable and opens only through desktop integration', async () => {
  const original = globalThis.window
  try {
    globalThis.window = {}
    const controller = {
      storage: { project_path: '/disk/<project>&stuff' },
      escapeHtml: text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    }
    let html = SettingsController.prototype.projectLocation.call(controller)
    assert.match(html, /\/disk\/&lt;project&gt;&amp;stuff/)
    assert.match(html, /select-text/)
    assert.match(html, /break-all/)
    assert.doesNotMatch(html, /<button/)
    let opened = false
    window.invasionStudioStorage = { openProjectFolder: async () => { opened = true } }
    html = SettingsController.prototype.projectLocation.call(controller)
    assert.match(html, /Open project folder/)
    await SettingsController.prototype.openProjectFolder.call(controller)
    assert.equal(opened, true)
    let error
    controller.showError = message => { error = message }
    window.invasionStudioStorage.openProjectFolder = async () => { throw new Error('Unavailable') }
    await SettingsController.prototype.openProjectFolder.call(controller)
    assert.equal(error, 'Unavailable')
  } finally { globalThis.window = original }
})
