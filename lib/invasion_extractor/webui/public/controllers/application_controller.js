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
}
