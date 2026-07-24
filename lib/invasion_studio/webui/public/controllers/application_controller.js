import { Controller } from "@hotwired/stimulus"

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
    const toast = document.createElement('div')
    toast.className = 'fixed bottom-4 right-4 bg-danger text-danger-fg px-4 py-2 rounded shadow-lg z-50 text-sm'
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => {
      toast.remove()
    }, 3000)
  }

  showSuccess(message) {
    const toast = document.createElement('div')
    toast.className = 'fixed bottom-4 right-4 bg-success text-success-fg px-4 py-2 rounded shadow-lg z-50 text-sm'
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => {
      toast.remove()
    }, 2000)
  }
}
