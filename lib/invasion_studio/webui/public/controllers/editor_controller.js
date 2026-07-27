import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["titleInput", "noteInput", "ratingContainer", "resultSelect", "deleteBtn", "restoreBtn", "finalizeBtn", "tagList", "tagInput", "tagSuggestions"]
  static values = {
    clipId: { type: String, default: "" }
  }

  connect() {
    this.debouncedSaveTitle = this.debounce(this.saveTitle.bind(this), 500)
    this.debouncedSaveNote = this.debounce(this.saveNote.bind(this), 500)
    this.onTagsChanged = () => this.refreshTagState()
    document.addEventListener('tags:changed', this.onTagsChanged)
  }

  disconnect() {
    document.removeEventListener('tags:changed', this.onTagsChanged)
    this.loadAbortController?.abort()
  }

  // Tags were renamed/deleted in settings — re-fetch the selected clip's
  // chips and the autocomplete options.
  async refreshTagState() {
    this.loadTagSuggestions()
    if (!this.clipIdValue) return
    try {
      const clip = await this.fetchJson('/api/clip/' + encodeURIComponent(this.clipIdValue))
      this.renderTags(clip.tags || [])
    } catch (err) {
      // The next clip selection re-renders the chips anyway.
    }
  }

  clipIdValueChanged() {
    if (this.clipIdValue) {
      this.loadClip()
    } else {
      this.reset()
    }
  }

  async loadClip() {
    const id = this.clipIdValue
    this.loadAbortController?.abort()
    this.loadAbortController = new AbortController()
    let clip
    try {
      clip = await this.fetchJson('/api/clip/' + encodeURIComponent(id), { signal: this.loadAbortController.signal })
    } catch (error) {
      if (error.name === 'AbortError') return
      this.reset()
      return
    }
    if (id !== this.clipIdValue) return

    this.titleInputTarget.value = clip.title || ''
    this.titleInputTarget.disabled = false
    this.titleInputTarget.placeholder = clip.filename

    this.noteInputTarget.value = clip.note || ''
    this.noteInputTarget.disabled = false

    this.renderStars(clip.rating || 0)
    this.renderResult(clip.result || '')
    this.resultSelectTarget.disabled = false

    if (clip.deleted) {
      this.deleteBtnTarget.style.display = 'none'
      this.restoreBtnTarget.style.display = 'inline-block'
    } else {
      this.deleteBtnTarget.style.display = 'inline-block'
      this.restoreBtnTarget.style.display = 'none'
    }

    const hasCuts = clip.cuts && clip.cuts.length > 0
    this.finalizeBtnTarget.style.display = hasCuts ? 'inline-block' : 'none'

    this.renderTags(clip.tags || [])
    this.tagInputTarget.disabled = false
    this.loadTagSuggestions()
  }

  reset() {
    this.titleInputTarget.value = 'No clip selected'
    this.titleInputTarget.disabled = true
    this.titleInputTarget.placeholder = 'Clip title (optional)'

    this.noteInputTarget.value = ''
    this.noteInputTarget.disabled = true

    this.renderStars(0)
    this.renderResult('')
    this.resultSelectTarget.disabled = true

    this.deleteBtnTarget.style.display = 'none'
    this.restoreBtnTarget.style.display = 'none'
    this.finalizeBtnTarget.style.display = 'none'

    this.renderTags([])
    this.tagInputTarget.value = ''
    this.tagInputTarget.disabled = true
  }

  tagInputChanged() {
    this.tagHighlight = -1
    this.renderTagSuggestions()
  }

  tagKeydown(event) {
    if (event.key === 'ArrowDown') {
      event.preventDefault()
      this.moveTagHighlight(1)
    } else if (event.key === 'ArrowUp') {
      event.preventDefault()
      this.moveTagHighlight(-1)
    } else if (event.key === 'Enter') {
      event.preventDefault()
      const picked = this.visibleTagSuggestions()[this.tagHighlight]
      if (picked) this.tagInputTarget.value = picked
      this.submitTag()
    } else if (event.key === 'Escape') {
      this.hideTagSuggestions()
    }
  }

  // mousedown (not click) so the pick lands before the input's blur hides
  // the dropdown; preventDefault keeps focus in the input.
  pickTagSuggestion(event) {
    const item = event.target.closest('[data-suggestion]')
    if (!item) return
    event.preventDefault()
    this.tagInputTarget.value = item.dataset.suggestion
    this.submitTag()
  }

  moveTagHighlight(delta) {
    const count = this.visibleTagSuggestions().length
    if (count === 0) return
    // -1 means "free typing"; ArrowUp from the first item returns to it.
    this.tagHighlight = Math.min(Math.max((this.tagHighlight ?? -1) + delta, -1), count - 1)
    this.renderTagSuggestions()
  }

  visibleTagSuggestions() {
    const query = this.tagInputTarget.value.trim().toLowerCase()
    const current = this.currentTags || []
    return (this.tagOptions || [])
      .filter(tag => !current.includes(tag))
      .filter(tag => tag.toLowerCase().includes(query))
  }

  renderTagSuggestions() {
    const suggestions = this.visibleTagSuggestions()
    if (suggestions.length === 0 || this.tagInputTarget.disabled) {
      this.hideTagSuggestions()
      return
    }
    this.tagSuggestionsTarget.hidden = false
    this.tagSuggestionsTarget.innerHTML = suggestions.map((tag, index) =>
      '<div class="px-2 py-1 text-xs cursor-pointer whitespace-nowrap ' +
      (index === this.tagHighlight ? 'bg-surface-hover text-text-primary' : 'text-text-secondary hover:bg-surface-hover') +
      '" data-suggestion="' + this.escapeAttribute(tag) + '">' + this.escapeHtml(tag) + '</div>'
    ).join('')
    this.tagSuggestionsTarget.children[this.tagHighlight]?.scrollIntoView({ block: 'nearest' })
  }

  hideTagSuggestions() {
    this.tagSuggestionsTarget.hidden = true
    this.tagHighlight = -1
  }

  async submitTag() {
    this.hideTagSuggestions()
    if (!this.clipIdValue) return
    const name = this.tagInputTarget.value.trim()
    if (!name) return
    this.tagInputTarget.value = ''
    try {
      const data = await this.fetchJson('/api/clip/' + encodeURIComponent(this.clipIdValue) + '/tags', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name })
      })
      this.renderTags(data.tags)
      this.loadTagSuggestions()
      this.dispatch('refresh', { detail: { reason: 'tags' } })
    } catch (err) {
      this.showError('Failed to add tag')
    }
  }

  async removeTag(event) {
    const chip = event.target.closest('[data-tag-name]')
    if (!chip || !this.clipIdValue) return
    try {
      const data = await this.fetchJson(
        '/api/clip/' + encodeURIComponent(this.clipIdValue) + '/tags/' + encodeURIComponent(chip.dataset.tagName),
        { method: 'DELETE' }
      )
      this.renderTags(data.tags)
      this.dispatch('refresh', { detail: { reason: 'tags' } })
    } catch (err) {
      this.showError('Failed to remove tag')
    }
  }

  renderTags(tags) {
    this.currentTags = tags
    this.tagListTarget.innerHTML = tags.map(tag =>
      '<span class="inline-flex items-center gap-1 bg-surface-secondary text-text-secondary border border-border px-2 py-0.5 rounded-full text-xs">' +
      this.escapeHtml(tag) +
      '<button type="button" data-tag-name="' + this.escapeAttribute(tag) + '" class="bg-transparent border-none text-text-muted cursor-pointer leading-none hover:text-text-primary" aria-label="Remove tag">&times;</button>' +
      '</span>'
    ).join('')
  }

  async loadTagSuggestions() {
    try {
      this.tagOptions = await this.fetchJson('/api/tags')
    } catch (err) {
      // Autocomplete is optional; adding tags still works without it.
    }
  }

  async saveTitle() {
    if (!this.clipIdValue) return
    const title = this.titleInputTarget.value
    const res = await fetch('/api/title', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: this.clipIdValue, title: title })
    })
    if (res.ok) {
      this.dispatch('refresh', { detail: { reason: 'title' } })
    }
  }

  async saveNote() {
    if (!this.clipIdValue) return
    const note = this.noteInputTarget.value
    const res = await fetch('/api/note', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: this.clipIdValue, note: note })
    })
    if (res.ok) {
      this.dispatch('refresh', { detail: { reason: 'note' } })
    }
  }

  async setRating(event) {
    const star = event.target.closest('[data-value]')
    if (!star) return
    if (!this.clipIdValue) return
    const rating = parseInt(star.dataset.value)
    try {
      const res = await fetch('/api/rating', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: this.clipIdValue, rating: rating })
      })
      if (res.ok) {
        this.renderStars(rating)
        this.dispatch('refresh', { detail: { reason: 'rating' } })
      } else {
        this.showError('Failed to save rating')
      }
    } catch (err) {
      this.showError('Failed to save rating')
    }
  }

  async setResult(event) {
    if (!this.clipIdValue) return
    const result = event.target.value
    try {
      const res = await fetch('/api/result', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: this.clipIdValue, result: result })
      })
      if (res.ok) {
        this.renderResult(result)
        this.dispatch('refresh', { detail: { reason: 'result' } })
      } else {
        this.showError('Failed to save result')
      }
    } catch (err) {
      this.showError('Failed to save result')
    }
  }

  async deleteClip() {
    if (!this.clipIdValue) return
    if (!confirm('Delete this clip? It will be moved to the trash folder.')) return
    const btn = this.deleteBtnTarget
    btn.textContent = 'Deleting...'
    btn.disabled = true
    btn.classList.add('opacity-50')
    try {
      const res = await fetch('/api/clip/' + encodeURIComponent(this.clipIdValue), {
        method: 'DELETE'
      })
      if (res.ok) {
        this.dispatch('refresh', { detail: { reason: 'deleted' } })
        this.showSuccess('Clip deleted')
      } else {
        this.showError('Failed to delete clip')
      }
    } catch (err) {
      this.showError('Failed to delete clip')
    } finally {
      btn.textContent = 'Delete'
      btn.disabled = false
      btn.classList.remove('opacity-50')
    }
  }

  async restoreClip() {
    if (!this.clipIdValue) return
    const btn = this.restoreBtnTarget
    btn.textContent = 'Restoring...'
    btn.disabled = true
    btn.classList.add('opacity-50')
    try {
      const res = await fetch('/api/clip/' + encodeURIComponent(this.clipIdValue), {
        method: 'DELETE'
      })
      if (res.ok) {
        this.dispatch('refresh', { detail: { reason: 'restored' } })
        this.showSuccess('Clip restored')
      } else {
        this.showError('Failed to restore clip')
      }
    } catch (err) {
      this.showError('Failed to restore clip')
    } finally {
      btn.textContent = 'Restore'
      btn.disabled = false
      btn.classList.remove('opacity-50')
    }
  }

  renderStars(rating) {
    this.ratingContainerTarget.querySelectorAll('[data-value]').forEach(star => {
      const value = parseInt(star.dataset.value)
      if (value <= rating) {
        star.classList.remove('text-star-empty')
        star.classList.add('text-accent')
      } else {
        star.classList.remove('text-accent')
        star.classList.add('text-star-empty')
      }
    })
  }

  renderResult(result) {
    this.resultSelectTarget.value = result
  }

  updateFinalizeButton(event) {
    if (event.detail.clipId !== this.clipIdValue) return

    this.finalizeBtnTarget.style.display = event.detail.hasCuts ? 'inline-block' : 'none'
  }

  async finalizeCuts() {
    if (!this.clipIdValue) return
    const hasCuts = this.finalizeBtnTarget.style.display !== 'none'
    if (!hasCuts) return

    if (!confirm('Finalize cuts? This will permanently remove the cut segments from the video. A backup will be saved to the .backup folder.')) return

    const btn = this.finalizeBtnTarget
    btn.textContent = 'Finalizing...'
    btn.disabled = true
    btn.classList.add('opacity-50')

    try {
      const res = await fetch('/api/clip/' + encodeURIComponent(this.clipIdValue) + '/finalize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      if (res.ok) {
        this.dispatch('cuts-finalized', { detail: { clipId: this.clipIdValue } })
        this.dispatch('refresh', { detail: { reason: 'finalized' } })
        this.showSuccess('Cuts finalized')
        this.finalizeBtnTarget.style.display = 'none'
      } else {
        this.showError('Failed to finalize cuts')
      }
    } catch (err) {
      this.showError('Failed to finalize cuts')
    } finally {
      btn.textContent = 'Finalize Cuts'
      btn.disabled = false
      btn.classList.remove('opacity-50')
    }
  }

}
