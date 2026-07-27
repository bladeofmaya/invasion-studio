import ApplicationController from "./application_controller.js"
import { renderIcons } from "../../frontend/icons.js"

export default class extends ApplicationController {
  static targets = ["overlay", "tab", "panel", "tagList"]

  open() {
    this.overlayTarget.style.display = 'flex'
    this.loadTags()
  }

  close() {
    this.overlayTarget.style.display = 'none'
  }

  backdropClose(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  switchCategory(event) {
    const category = event.currentTarget.dataset.category
    this.tabTargets.forEach(tab => {
      const active = tab.dataset.category === category
      tab.classList.toggle('bg-surface-hover', active)
      tab.classList.toggle('text-text-primary', active)
      tab.classList.toggle('text-text-muted', !active)
    })
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.category !== category
    })
  }

  async loadTags() {
    try {
      this.tags = await this.fetchJson('/api/tags/details')
      this.renderTags()
    } catch (err) {
      this.tagListTarget.innerHTML = '<div class="text-sm text-text-muted">Failed to load tags.</div>'
    }
  }

  renderTags() {
    if (!this.tags.length) {
      this.tagListTarget.innerHTML = '<div class="text-sm text-text-muted">No tags yet. Add tags to clips in the editor.</div>'
      return
    }
    this.tagListTarget.innerHTML = this.tags.map(tag =>
      '<div class="flex items-center gap-2 bg-surface-secondary border border-border rounded px-3 py-2" data-name="' + this.escapeAttribute(tag.name) + '">' +
      '<span class="text-sm text-text-primary min-w-0 overflow-hidden text-ellipsis whitespace-nowrap">' + this.escapeHtml(tag.name) + '</span>' +
      '<span class="bg-surface text-text-muted border border-border rounded-full px-2 py-0.5 text-xs" title="' + tag.clip_count + ' clip(s) have this tag">' + tag.clip_count + '</span>' +
      '<span class="ml-auto flex gap-1 shrink-0">' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-text-primary hover:bg-surface-hover" title="Rename" aria-label="Rename" data-action="click->settings#startRename"><i data-lucide="pencil" class="size-3.5"></i></button>' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-danger hover:bg-surface-hover" title="Delete" aria-label="Delete" data-action="click->settings#deleteTag"><i data-lucide="trash-2" class="size-3.5"></i></button>' +
      '</span>' +
      '</div>'
    ).join('')
    renderIcons(this.tagListTarget)
  }

  startRename(event) {
    const row = event.currentTarget.closest('[data-name]')
    row.innerHTML =
      '<input type="text" class="bg-input-bg text-text-primary border border-input-border px-2 py-1 rounded text-sm min-w-0 flex-1 focus:outline-none focus:border-input-focus-ring" value="' + this.escapeAttribute(row.dataset.name) + '" data-action="keydown->settings#renameKeydown">' +
      '<span class="ml-auto flex gap-1 shrink-0">' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-success hover:bg-surface-hover" title="Save" aria-label="Save" data-action="click->settings#saveRename"><i data-lucide="check" class="size-3.5"></i></button>' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-danger hover:bg-surface-hover" title="Cancel" aria-label="Cancel" data-action="click->settings#cancelRename"><i data-lucide="x" class="size-3.5"></i></button>' +
      '</span>'
    renderIcons(row)
    const input = row.querySelector('input')
    input.focus()
    input.select()
  }

  renameKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      this.saveRename(event)
    } else if (event.key === 'Escape') {
      event.preventDefault()
      this.renderTags()
    }
  }

  cancelRename() {
    this.renderTags()
  }

  async saveRename(event) {
    const row = event.currentTarget.closest('[data-name]')
    const oldName = row.dataset.name
    const newName = row.querySelector('input').value.trim()
    if (!newName || newName === oldName) {
      this.renderTags()
      return
    }
    try {
      const res = await fetch('/api/tags/rename', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ old_name: oldName, new_name: newName })
      })
      if (res.ok) {
        this.showSuccess('Tag renamed')
        this.notifyTagsChanged()
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to rename tag')
      }
    } catch (err) {
      this.showError('Failed to rename tag')
    }
    this.loadTags()
  }

  async deleteTag(event) {
    const row = event.currentTarget.closest('[data-name]')
    const name = row.dataset.name
    const tag = (this.tags || []).find(t => t.name === name)
    const count = tag ? tag.clip_count : 0
    if (!confirm('Delete tag "' + name + '"? It will be removed from ' + count + ' clip(s). This cannot be undone.')) return
    try {
      const res = await fetch('/api/tags/' + encodeURIComponent(name), { method: 'DELETE' })
      if (res.ok) {
        this.showSuccess('Tag deleted')
        this.notifyTagsChanged()
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to delete tag')
      }
    } catch (err) {
      this.showError('Failed to delete tag')
    }
    this.loadTags()
  }

  // The clip list re-fetches (which also refreshes its tag filter options);
  // the editor reloads the selected clip's chips and its suggestions.
  notifyTagsChanged() {
    document.dispatchEvent(new CustomEvent('tags:changed'))
    document.getElementById('clip-panel')?.dispatchEvent(new CustomEvent('clip-list:refresh'))
  }
}
