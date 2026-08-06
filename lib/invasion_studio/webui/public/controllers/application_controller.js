import { Controller } from "@hotwired/stimulus"
import { renderIcons } from "../../frontend/icons.js"

export default class extends Controller {
  getNavState() {
    // ~= (word match): the root element hosts multiple controllers
    // ("router navigation"), so an exact attribute match would miss it
    const navEl = document.querySelector('[data-controller~="navigation"]')
    if (!navEl) return { view: 'all', group: '' }
    return {
      view: navEl.dataset.navigationCurrentViewValue || 'all',
      group: navEl.dataset.navigationSelectedGroupValue || ''
    }
  }

  // Route all app-state changes (view/group/filter/clip selection) through
  // the router controller — the single source of truth for URL <-> state.
  // Only call this from user-action handlers, never from *ValueChanged
  // callbacks (the router's apply() triggers those; dispatching from them
  // would loop).
  navigateTo(state, { replace = false } = {}) {
    this.element.dispatchEvent(new CustomEvent('router:navigate', {
      bubbles: true,
      detail: { state, replace }
    }))
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  escapeAttribute(text) {
    return this.escapeHtml(text).replaceAll('"', '&quot;').replaceAll("'", '&#39;')
  }

  async fetchJson(url, options = {}) {
    const headers = { Accept: 'application/json', ...(options.headers || {}) }
    const response = await fetch(url, { ...options, headers })
    let data = null
    try {
      data = await response.json()
    } catch (error) {
      // Aborting mid-body-read must surface as an abort, not a null result.
      if (error.name === 'AbortError') throw error
      // A non-JSON error is still represented consistently below.
    }
    if (!response.ok) {
      throw new Error(data?.error || `Request failed (${response.status})`)
    }
    return data
  }

  formatDuration(seconds) {
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    const s = Math.floor(seconds % 60)
    if (h > 0) return h + 'h ' + m + 'm'
    if (m > 0) return m + 'm ' + s + 's'
    return s + 's'
  }

  // Debounce utility for limiting rapid-fire events
  debounce(fn, delay = 300) {
    let timeoutId
    return (...args) => {
      clearTimeout(timeoutId)
      timeoutId = setTimeout(() => fn.apply(this, args), delay)
    }
  }

  // Error boundary: wrap async actions with consistent error handling
  async withErrorBoundary(asyncFn, { loadingTarget = null, errorMessage = 'Something went wrong' } = {}) {
    if (loadingTarget) {
      loadingTarget.classList.add('opacity-50', 'pointer-events-none')
    }
    try {
      return await asyncFn()
    } catch (err) {
      console.error(err)
      this.showError(errorMessage)
    } finally {
      if (loadingTarget) {
        loadingTarget.classList.remove('opacity-50', 'pointer-events-none')
      }
    }
  }

  showError(message) {
    this.showNotification(message, { type: 'error', duration: 3000 })
  }

  showSuccess(message) {
    this.showNotification(message, { type: 'success', duration: 2000 })
  }

  showNotification(message, { type, duration }) {
    const container = this.notificationContainer()
    const toast = document.createElement('div')
    const isError = type === 'error'
    toast.className = [
      'pointer-events-auto flex items-start gap-3 min-w-64 max-w-sm',
      'bg-surface text-text-primary border border-border rounded-lg shadow-lg px-3.5 py-3 text-sm',
      isError ? 'border-l-4 border-l-danger' : 'border-l-4 border-l-success'
    ].join(' ')
    toast.setAttribute('role', isError ? 'alert' : 'status')

    const icon = document.createElement('i')
    icon.dataset.lucide = isError ? 'circle-alert' : 'circle-check'
    icon.className = 'size-5 shrink-0 ' + (isError ? 'text-danger' : 'text-success')

    const text = document.createElement('span')
    text.className = 'leading-5 break-words'
    text.textContent = message
    toast.append(icon, text)
    container.appendChild(toast)
    renderIcons(toast)

    setTimeout(() => {
      toast.remove()
      if (!container.hasChildNodes()) container.remove()
    }, duration)
  }

  notificationContainer() {
    let container = document.querySelector('[data-notification-container]')
    if (container) return container

    container = document.createElement('div')
    container.dataset.notificationContainer = ''
    container.className = 'fixed top-16 right-4 z-50 flex flex-col items-end gap-2 pointer-events-none'
    container.setAttribute('aria-live', 'polite')
    container.setAttribute('aria-atomic', 'false')
    document.body.appendChild(container)
    return container
  }
}
