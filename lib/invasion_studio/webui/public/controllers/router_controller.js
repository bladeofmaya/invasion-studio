import { Controller } from "@hotwired/stimulus"

// Pure URL <-> state mapping. State shape:
// { view: 'all'|'groups'|'group-detail', group: string, filter: string, sort: string,
//   q: string, tag: string, rating: string, result: string, clipId: string }
//
// URL scheme:
//   /                            all clips, filter=unassigned (default), project order
//   /?filter=deleted             all clips, deleted filter
//   /?sort=rating-desc           all clips, sorted by rating (high first)
//   /?q=parry&tag=gank           all clips, text search + tag/rating/result filters
//   /clips/:id                   all clips, clip selected
//   /groups                      groups grid
//   /groups/:name                group detail
//   /groups/:name/clips/:id      group detail, clip selected

export const DEFAULT_FILTER = 'unassigned'
const SEARCH_DEFAULTS = { q: '', tag: '', rating: '', result: '' }
const DEFAULT_STATE = { view: 'all', group: '', filter: DEFAULT_FILTER, sort: '', ...SEARCH_DEFAULTS, clipId: '' }

export function parseUrl(pathname, search) {
  const params = new URLSearchParams(search)
  const filter = params.get('filter') || DEFAULT_FILTER
  const sort = params.get('sort') || ''
  const searchState = {
    q: params.get('q') || '',
    tag: params.get('tag') || '',
    rating: params.get('rating') || '',
    result: params.get('result') || ''
  }
  const segments = pathname.split('/').filter(Boolean).map(decodeURIComponent)

  if (segments.length === 0) {
    return { view: 'all', group: '', filter: filter, sort: sort, ...searchState, clipId: '' }
  }
  if (segments[0] === 'clips' && segments.length === 2) {
    return { view: 'all', group: '', filter: filter, sort: sort, ...searchState, clipId: segments[1] }
  }
  if (segments[0] === 'groups') {
    if (segments.length === 1) {
      return { view: 'groups', group: '', filter: DEFAULT_FILTER, sort: '', ...SEARCH_DEFAULTS, clipId: '' }
    }
    if (segments.length === 2) {
      return { view: 'group-detail', group: segments[1], filter: DEFAULT_FILTER, sort: '', ...SEARCH_DEFAULTS, clipId: '' }
    }
    if (segments.length === 4 && segments[2] === 'clips') {
      return { view: 'group-detail', group: segments[1], filter: DEFAULT_FILTER, sort: '', ...SEARCH_DEFAULTS, clipId: segments[3] }
    }
  }
  return { ...DEFAULT_STATE }
}

export function serializeUrl(state) {
  const enc = encodeURIComponent
  if (state.view === 'groups') {
    return '/groups'
  }
  if (state.view === 'group-detail') {
    return state.clipId
      ? '/groups/' + enc(state.group) + '/clips/' + enc(state.clipId)
      : '/groups/' + enc(state.group)
  }
  const base = state.clipId ? '/clips/' + enc(state.clipId) : '/'
  const params = new URLSearchParams()
  if (state.filter && state.filter !== DEFAULT_FILTER) params.set('filter', state.filter)
  if (state.sort) params.set('sort', state.sort)
  if (state.q) params.set('q', state.q)
  if (state.tag) params.set('tag', state.tag)
  if (state.rating) params.set('rating', state.rating)
  if (state.result) params.set('result', state.result)
  const qs = params.toString()
  return base + (qs ? '?' + qs : '')
}

// Single source of truth for app state. Other controllers request state
// changes by dispatching a bubbling 'router:navigate' CustomEvent (see
// ApplicationController#navigateTo); the router updates the URL via the
// History API and applies the state to the canonical Stimulus values,
// whose existing xxxValueChanged callbacks do the rendering.
export default class extends Controller {
  connect() {
    this.applying = false
    this.state = parseUrl(window.location.pathname, window.location.search)

    this.onNavigate = (event) => {
      this.navigate(event.detail.state || {}, { replace: !!event.detail.replace })
    }
    this.element.addEventListener('router:navigate', this.onNavigate)

    this.onPopstate = () => {
      this.state = parseUrl(window.location.pathname, window.location.search)
      this.apply(this.state)
    }
    window.addEventListener('popstate', this.onPopstate)

    // Hydrate from the URL, canonicalizing it (e.g. strip ?filter=everything)
    history.replaceState(null, '', serializeUrl(this.state))
    this.apply(this.state)
  }

  disconnect() {
    this.element.removeEventListener('router:navigate', this.onNavigate)
    window.removeEventListener('popstate', this.onPopstate)
  }

  navigate(partialState, { replace = false } = {}) {
    if (this.applying) return
    this.state = { ...this.state, ...partialState }
    const url = serializeUrl(this.state)
    if (url !== window.location.pathname + window.location.search) {
      if (replace) {
        history.replaceState(null, '', url)
      } else {
        history.pushState(null, '', url)
      }
    }
    this.apply(this.state)
  }

  apply(state) {
    this.applying = true
    try {
      const navEl = document.querySelector('[data-controller~="navigation"]')
      const listEl = document.querySelector('[data-controller~="clip-list"]')
      if (navEl) {
        navEl.dataset.navigationSelectedGroupValue = state.group
        navEl.dataset.navigationCurrentViewValue = state.view
      }
      if (listEl) {
        listEl.dataset.clipListViewValue = state.view
        listEl.dataset.clipListGroupValue = state.group
        listEl.dataset.clipListFilterValue = state.filter
        listEl.dataset.clipListSortValue = state.sort
        listEl.dataset.clipListQValue = state.q
        listEl.dataset.clipListTagValue = state.tag
        listEl.dataset.clipListRatingValue = state.rating
        listEl.dataset.clipListResultValue = state.result
        listEl.dataset.clipListSelectedClipIdValue = state.clipId
      }
    } finally {
      this.applying = false
    }
  }
}
