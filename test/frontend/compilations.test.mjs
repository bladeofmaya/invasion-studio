import assert from 'node:assert/strict'
import test from 'node:test'
import GroupController from '../../lib/invasion_studio/webui/public/controllers/group_manager_controller.js'

test('active and archived compilation tabs show separate collections', () => {
  const controller = { archived: false, groupStats: [{ name: 'Active', archived: false }, { name: 'Old', archived: true }] }
  assert.deepEqual(GroupController.prototype.visibleGroups.call(controller).map(g => g.name), ['Active'])
  controller.archived = true
  assert.deepEqual(GroupController.prototype.visibleGroups.call(controller).map(g => g.name), ['Old'])
})

test('archive and restore send the requested status and refresh after success', async () => {
  for (const archived of [true, false]) {
    let sent
    let refreshed = false
    const button = { disabled: false, dataset: { archived: String(archived) }, closest: () => ({ dataset: { group: 'My Compilation' } }) }
    const controller = {
      fetchJson: async (url, options) => { sent = { url, body: JSON.parse(options.body) } },
      fetchAndRender: async () => { refreshed = true }, dispatchGroupsRefresh() {}, showSuccess() {}, showError: assert.fail
    }
    await GroupController.prototype.archiveGroup.call(controller, { currentTarget: button })
    assert.deepEqual(sent, { url: '/api/groups/My%20Compilation', body: { archived } })
    assert.equal(refreshed, true)
    assert.equal(button.disabled, false)
  }
})

test('description autosaves in order, including clearing, without rebuilding the cards', async () => {
  const status = {}
  const card = { dataset: { group: 'Best' }, querySelector: () => status }
  const input = { value: 'First draft', closest: () => card }
  const requests = []
  const controller = {
    descriptionDrafts: new Map(), groupStats: [{ name: 'Best', description: 'Existing description' }],
    fetchJson: async (url, options) => { requests.push(JSON.parse(options.body).description) },
    persistDescription: GroupController.prototype.persistDescription,
    showError: assert.fail
  }
  GroupController.prototype.queueDescription.call(controller, { currentTarget: input })
  input.value = ''
  GroupController.prototype.queueDescription.call(controller, { currentTarget: input })
  await GroupController.prototype.saveDescription.call(controller, { currentTarget: input })
  assert.deepEqual(requests, [''])
  assert.equal(controller.groupStats[0].description, '')
  assert.equal(status.textContent, '')
  controller.fetchJson = async () => { throw new Error('Offline') }
  input.value = 'Keep this draft'
  GroupController.prototype.queueDescription.call(controller, { currentTarget: input })
  await GroupController.prototype.saveDescription.call(controller, { currentTarget: input })
  assert.equal(controller.descriptionDrafts.get('Best').description, 'Keep this draft')
  assert.match(status.textContent, /Offline/)
})

test('autosave waits for an earlier request before sending the latest description', async () => {
  const status = {}
  const card = { dataset: { group: 'Best' }, querySelector: () => status }
  const input = { value: 'First', closest: () => card }
  let finishFirst
  const requests = []
  const controller = {
    descriptionDrafts: new Map(), groupStats: [{ name: 'Best', description: '' }],
    fetchJson: async (url, options) => {
      requests.push(JSON.parse(options.body).description)
      if (requests.length === 1) await new Promise(resolve => { finishFirst = resolve })
    },
    persistDescription: GroupController.prototype.persistDescription
  }
  const event = { currentTarget: input }
  GroupController.prototype.queueDescription.call(controller, event)
  const first = GroupController.prototype.saveDescription.call(controller, event)
  await Promise.resolve()
  input.value = 'Latest'
  GroupController.prototype.queueDescription.call(controller, event)
  const latest = GroupController.prototype.saveDescription.call(controller, event)
  assert.deepEqual(requests, ['First'])
  finishFirst()
  await Promise.all([first, latest])
  assert.deepEqual(requests, ['First', 'Latest'])
  assert.equal(controller.groupStats[0].description, 'Latest')
})
