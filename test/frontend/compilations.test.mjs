import assert from 'node:assert/strict'
import test from 'node:test'
import GroupController from '../../lib/invasion_studio/webui/public/controllers/group_manager_controller.js'

const groups = [
  { name: 'Older', description: 'Daggers', archived: false, updated_at: '2026-01-01' },
  { name: 'Newest', description: 'Twinblade', archived: false, updated_at: '2026-03-01' },
  { name: 'Published', archived: true, updated_at: '2026-04-01', archived_at: '2026-02-01' },
  { name: 'Unpublished', archived: true, updated_at: '2026-02-01', archived_at: '2026-03-01' }
]

function controller(overrides = {}) {
  return { archived: false, groupStats: groups, searchTarget: { value: '' }, sortTarget: { value: 'updated' }, ...overrides }
}

test('compilations filter by status and description and sort independently', () => {
  const state = controller()
  const names = () => GroupController.prototype.visibleGroups.call(state).map(group => group.name)
  assert.deepEqual(names(), ['Newest', 'Older'])
  state.searchTarget.value = 'DAGGERS'
  assert.deepEqual(names(), ['Older'])
  state.searchTarget.value = ''
  state.archived = true
  state.sortTarget.value = 'archived'
  assert.deepEqual(names(), ['Unpublished', 'Published'])
  state.sortTarget.value = 'name'
  assert.deepEqual(names(), ['Published', 'Unpublished'])
  assert.equal(groups[0].name, 'Older', 'Sorting does not mutate the cached collection')
})

test('restore refreshes only after the update succeeds', async () => {
  const operations = []
  const state = {
    update: async (name, changes) => operations.push([name, changes]),
    refresh: async () => operations.push('refresh'), showSuccess() {}, showError: assert.fail
  }
  await GroupController.prototype.restore.call(state, { name: 'Video' })
  assert.deepEqual(operations, [['Video', { archived: false }], 'refresh'])
  state.update = async () => { throw new Error('Offline') }
  state.showError = message => operations.push(message)
  await GroupController.prototype.restore.call(state, { name: 'Video' })
  assert.equal(operations.at(-1), 'Offline')
  assert.equal(operations.filter(value => value === 'refresh').length, 1)
})

test('a stale compilation response cannot replace newer details', async () => {
  let finishFirst
  let call = 0
  const state = { fetchJson: () => ++call === 1 ? new Promise(resolve => { finishFirst = resolve }) : Promise.resolve([{ name: 'New' }]) }
  const first = GroupController.prototype.fetchGroupStats.call(state)
  await GroupController.prototype.fetchGroupStats.call(state)
  finishFirst([{ name: 'Old' }])
  await first
  assert.deepEqual(state.groupStats, [{ name: 'New' }])
})
