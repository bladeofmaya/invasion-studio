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

test('cache clearing sends only the selected scope and warns that OCR is shared', async () => {
  const original = globalThis.confirm
  try {
    let prompt, request
    globalThis.confirm = message => { prompt = message; return true }
    const controller = {
      fetchJson: async (url, options) => { request = { url, body: JSON.parse(options.body) }; return { freed_bytes: 1 } },
      showSuccess() {}, showError: assert.fail, formatBytes: () => '1 B', loadStorage() {}
    }
    await SettingsController.prototype.clearCache.call(controller, { currentTarget: { dataset: { scope: 'ocr' } } })
    assert.match(prompt, /all projects/)
    assert.deepEqual(request, { url: '/api/storage/clear-cache', body: { scope: 'ocr' } })
    request = null
    globalThis.confirm = () => false
    await SettingsController.prototype.clearCache.call(controller, { currentTarget: { dataset: { scope: 'ocr' } } })
    assert.equal(request, null)
    await SettingsController.prototype.clearCache.call(controller, { currentTarget: { dataset: { scope: 'preview' } } })
    assert.deepEqual(request.body, { scope: 'preview' })
  } finally { globalThis.confirm = original }
})

test('dependency field saves one tool and blank restores detection', async () => {
  let request
  const input = { value: '/custom tool' }
  const status = {}
  const form = { dataset: { tool: 'ffmpeg' }, querySelector: selector => selector === 'input' ? input : status }
  const controller = {
    fetchJson: async (url, options) => { request = { url, body: JSON.parse(options.body) }; return { tools: [] } },
    renderDependencies() { this.rendered = true }
  }
  const event = { preventDefault() {}, currentTarget: form }
  await SettingsController.prototype.saveDependency.call(controller, event)
  assert.deepEqual(request, { url: '/api/settings/dependencies', body: { ffmpeg: '/custom tool' } })
  input.value = ''
  await SettingsController.prototype.saveDependency.call(controller, event)
  assert.deepEqual(request.body, { ffmpeg: '' })
  controller.fetchJson = async () => { throw new Error('Not executable') }
  controller.rendered = false
  await SettingsController.prototype.saveDependency.call(controller, event)
  assert.equal(controller.rendered, false)
  assert.equal(status.textContent, 'Not executable')
})
