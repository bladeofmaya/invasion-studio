import assert from 'node:assert/strict'
import test from 'node:test'
import { parseUrl, serializeUrl } from '../../lib/invasion_studio/webui/public/controllers/router_controller.js'
import ExtractionController from '../../lib/invasion_studio/webui/public/controllers/extraction_controller.js'
import NavigationController from '../../lib/invasion_studio/webui/public/controllers/navigation_controller.js'

test('Import deep links round trip without clip filters or selection', () => {
  const state = parseUrl('/import', '?filter=deleted&q=old')
  assert.equal(state.view, 'import')
  assert.equal(state.clipId, '')
  assert.equal(state.q, '')
  assert.equal(serializeUrl(state), '/import')
  assert.equal(parseUrl('/clips/clip1', '').clipId, 'clip1')
  assert.equal(serializeUrl({ view: 'groups' }), '/groups')
})

test('Import hides the library and preview, and Clips restores them', () => {
  const controller = { currentViewValue: 'import', hasMainTarget: true }
  for (const name of ['clipPanel', 'importPanel', 'backBtn', 'groupGrid', 'previewPanel', 'main']) {
    controller[`${name}Target`] = { style: {} }
  }
  NavigationController.prototype.updateVisibility.call(controller)
  assert.equal(controller.importPanelTarget.style.display, 'block')
  assert.equal(controller.clipPanelTarget.style.display, 'none')
  assert.equal(controller.previewPanelTarget.style.display, 'none')
  assert.equal(controller.mainTarget.style.gridTemplateColumns, '1fr')
  controller.currentViewValue = 'all'
  NavigationController.prototype.updateVisibility.call(controller)
  assert.equal(controller.importPanelTarget.style.display, 'none')
  assert.equal(controller.clipPanelTarget.style.display, 'flex')
  assert.equal(controller.previewPanelTarget.style.display, 'flex')
})



test('Extraction submits the ordered selection and options, with project chosen by the server', async () => {
  let request
  const controller = {
    extractionOptions: ExtractionController.prototype.extractionOptions,
    hasAllowReimportTarget: true, allowReimportTarget: { checked: true },
    fieldsTarget: { disabled: false }, pathsTarget: { value: '/second.mp4\n /first.mp4 \n' },
    threadsTarget: { value: '8' }, workersTarget: { value: '4' }, fpsTarget: { value: '1' },
    padStartTarget: { value: '10' }, padEndTarget: { value: '7.5' },
    hwaccelTarget: { checked: true }, noCacheTarget: { checked: false },
    fetchJson: async (url, options) => { request = { url, ...options }; return { status: 'running' } },
    renderStatus: state => assert.equal(state.status, 'running'),
    schedulePoll: () => {}, showError: message => assert.fail(message)
  }
  await ExtractionController.prototype.start.call(controller, { preventDefault() {} })
  assert.equal(request.url, '/api/extraction')
  assert.equal(request.method, 'POST')
  assert.deepEqual(JSON.parse(request.body), {
    paths: ['/second.mp4', '/first.mp4'],
    allow_reimport: true,
    options: { ffmpeg_threads: 8, ocr_workers: 4, fps: 1, pad_start: 10, pad_end: 7.5, hwaccel: true, no_cache: false }
  })
  assert.equal(controller.fieldsTarget.disabled, true)
  assert.equal(controller.allowReimportTarget.checked, false)
})

test('Running extraction disables resubmission and reports per-file progress', () => {
  const controller = {
    fieldsTarget: {}, progressTarget: {}, viewClipsTarget: {}, statusTarget: {}
  }
  ExtractionController.prototype.renderStatus.call(controller, {
    status: 'running', stage: 'ocr', file: '<recording>.mp4', current: 10, total: 100
  })
  assert.equal(controller.fieldsTarget.disabled, true)
  assert.equal(controller.progressTarget.value, 10)
  assert.equal(controller.progressTarget.max, 100)
  assert.equal(controller.statusTarget.textContent, 'Reading recording: <recording>.mp4 (10/100)')
})

test('Extraction settings save in order without recording paths and report failures', async () => {
  const controller = {
    settingsStatusTarget: {},
    threadsTarget: { value: '8', checkValidity: () => true },
    workersTarget: { value: '2', checkValidity: () => true },
    fpsTarget: { value: '1', checkValidity: () => true },
    padStartTarget: { value: '0', checkValidity: () => true },
    padEndTarget: { value: '4.5', checkValidity: () => true },
    hwaccelTarget: { checked: true }, noCacheTarget: { checked: false },
    pathsTarget: { value: '/private/file.mp4' },
    extractionOptions: ExtractionController.prototype.extractionOptions
  }
  const requests = []
  controller.fetchJson = async (url, request) => {
    assert.equal(url, '/api/settings/extraction')
    assert.equal(request.method, 'PUT')
    requests.push(JSON.parse(request.body))
  }
  const first = ExtractionController.prototype.saveSettings.call(controller)
  controller.threadsTarget.value = '16'
  const second = ExtractionController.prototype.saveSettings.call(controller)
  await Promise.all([first, second])
  assert.deepEqual(requests.map(r => r.ffmpeg_threads), [8, 16])
  assert.equal(requests[0].pad_start, 0)
  assert.equal(requests[0].no_cache, false)
  assert.equal('paths' in requests[0], false)
  assert.match(controller.settingsStatusTarget.textContent, /saved/i)
  controller.fetchJson = async () => { throw new Error('Offline') }
  await ExtractionController.prototype.saveSettings.call(controller)
  assert.match(controller.settingsStatusTarget.textContent, /Could not save.*Offline/)
  controller.threadsTarget.checkValidity = () => false
  await ExtractionController.prototype.saveSettings.call(controller)
  assert.match(controller.settingsStatusTarget.textContent, /valid/i)
})
