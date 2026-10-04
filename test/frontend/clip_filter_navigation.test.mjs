import assert from 'node:assert/strict'
import test from 'node:test'
import Router, { parseUrl } from '../../lib/invasion_studio/webui/public/controllers/router_controller.js'
import Navigation from '../../lib/invasion_studio/webui/public/controllers/navigation_controller.js'

test('tab switches preserve clip filters, while history and explicit navigation take precedence', () => {
  const previous = { window: globalThis.window, document: globalThis.document, history: globalThis.history }
  globalThis.window = { location: { pathname: '/', search: '' } }
  globalThis.document = { querySelector: () => null }
  globalThis.history = { pushState() {}, replaceState() {} }
  try {
    const router = { state: parseUrl('/clips/remember-me', '?filter=assigned&sort=rating-desc&q=parry&tag=duel&rating=4&result=win'), apply: Router.prototype.apply }
    router.apply(router.state)
    const expected = { ...router.clipsViewState }
    const navigate = state => Router.prototype.navigate.call(router, state)
    Navigation.prototype.switchView.call({ navigateTo: navigate }, { currentTarget: { dataset: { view: 'groups' } } })
    navigate({ view: 'group-detail', group: 'Highlights', clipId: 'another-clip' })
    navigate({ view: 'import', group: '' })
    Navigation.prototype.switchView.call({ navigateTo: navigate }, { currentTarget: { dataset: { view: 'all' } } })
    assert.deepEqual(router.clipsViewState, expected)
    assert.equal(router.state.group, '')
    assert.equal(router.state.clipId, 'remember-me')

    // A history URL is authoritative and becomes the new remembered selection.
    router.state = parseUrl('/', '?filter=unassigned&tag=magic')
    router.apply(router.state)
    navigate({ view: 'groups' })
    navigate({ view: 'all' })
    assert.equal(router.state.filter, 'unassigned')
    assert.equal(router.state.tag, 'magic')
    assert.equal(router.state.q, '')
    assert.equal(router.state.clipId, '')

    navigate({ view: 'import' })
    navigate({ view: 'all', filter: 'everything', sort: 'newest', q: '', tag: '', rating: '', result: '', clipId: '' })
    assert.equal(router.state.filter, 'everything')
    assert.equal(router.state.sort, 'newest')
    assert.equal(router.state.clipId, '')
    assert.equal(router.state.tag, '')
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete globalThis[key]
      else globalThis[key] = value
    }
  }
})
