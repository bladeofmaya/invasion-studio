import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  getNavState() {
    const navEl = document.querySelector('[data-controller="navigation"]')
    if (!navEl) return { view: 'all', group: '' }
    return {
      view: navEl.dataset.navigationCurrentViewValue || 'all',
      group: navEl.dataset.navigationSelectedGroupValue || ''
    }
  }

  resetEditor() {
    const clipListEl = document.querySelector('[data-controller="clip-list"]')
    if (clipListEl) {
      clipListEl.dataset.clipListSelectedClipIdValue = ''
    }
    document.getElementById('meta-filename').textContent = '—'
    const videoPlayerEl = document.querySelector('[data-controller="video-player"]')
    if (videoPlayerEl) {
      videoPlayerEl.dataset.videoPlayerClipIdValue = ''
      videoPlayerEl.dataset.videoPlayerSrcValue = ''
      videoPlayerEl.dataset.videoPlayerCutsValue = '[]'
    }
    const editorEl = document.querySelector('[data-controller="editor"]')
    if (editorEl) {
      editorEl.dataset.editorClipIdValue = ''
    }
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
