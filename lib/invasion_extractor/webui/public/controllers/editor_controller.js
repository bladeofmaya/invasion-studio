import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["titleInput", "noteInput", "ratingContainer", "resultContainer", "deleteBtn", "restoreBtn"]
  static values = {
    clipId: { type: String, default: "" }
  }

  connect() {
    this.debouncedSaveTitle = this.debounce(this.saveTitle.bind(this), 500)
    this.debouncedSaveNote = this.debounce(this.saveNote.bind(this), 500)
  }

  clipIdValueChanged() {
    if (this.clipIdValue) {
      this.loadClip()
    } else {
      this.reset()
    }
  }

  async loadClip() {
    const res = await fetch('/api/clip/' + encodeURIComponent(this.clipIdValue))
    const clip = await res.json()
    if (clip.error) {
      this.reset()
      return
    }

    this.titleInputTarget.value = clip.title || ''
    this.titleInputTarget.disabled = false
    this.titleInputTarget.placeholder = clip.filename

    this.noteInputTarget.value = clip.note || ''
    this.noteInputTarget.disabled = false

    this.renderStars(clip.rating || 0)
    this.renderResult(clip.result || '')

    if (clip.deleted) {
      this.deleteBtnTarget.style.display = 'none'
      this.restoreBtnTarget.style.display = 'inline-block'
    } else {
      this.deleteBtnTarget.style.display = 'inline-block'
      this.restoreBtnTarget.style.display = 'none'
    }

  }

  reset() {
    this.titleInputTarget.value = 'No clip selected'
    this.titleInputTarget.disabled = true
    this.titleInputTarget.placeholder = 'Clip title (optional)'

    this.noteInputTarget.value = ''
    this.noteInputTarget.disabled = true

    this.renderStars(0)
    this.renderResult('')

    this.deleteBtnTarget.style.display = 'none'
    this.restoreBtnTarget.style.display = 'none'
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
    const radios = this.resultContainerTarget.querySelectorAll('input[name="result"]')
    radios.forEach(radio => {
      radio.checked = radio.value === result
    })
  }


}
