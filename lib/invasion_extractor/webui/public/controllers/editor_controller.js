import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["titleInput", "noteInput", "ratingContainer", "resultContainer", "deleteBtn", "restoreBtn", "saveStatus"]
  static values = {
    clipId: { type: String, default: "" }
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

    this.setStatus('')
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

    this.setStatus('')
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
      this.setStatus('Title saved')
      this.dispatch('refresh', { detail: { reason: 'title' } })
    } else {
      this.setStatus('Error saving title')
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
      this.setStatus('Saved')
      this.dispatch('refresh', { detail: { reason: 'note' } })
    } else {
      this.setStatus('Error saving')
    }
  }

  async setRating(event) {
    const star = event.target.closest('[data-value]')
    if (!star) return
    if (!this.clipIdValue) return
    const rating = parseInt(star.dataset.value)
    const res = await fetch('/api/rating', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: this.clipIdValue, rating: rating })
    })
    if (res.ok) {
      this.renderStars(rating)
      this.setStatus('Rating saved')
      this.dispatch('refresh', { detail: { reason: 'rating' } })
    }
  }

  async setResult(event) {
    if (!this.clipIdValue) return
    const result = event.target.value
    const res = await fetch('/api/result', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: this.clipIdValue, result: result })
    })
    if (res.ok) {
      this.renderResult(result)
      this.setStatus('Result saved')
      this.dispatch('refresh', { detail: { reason: 'result' } })
    }
  }

  async deleteClip() {
    if (!this.clipIdValue) return
    if (!confirm('Delete this clip? It will be moved to the trash folder.')) return
    const res = await fetch('/api/clip/' + encodeURIComponent(this.clipIdValue), {
      method: 'DELETE'
    })
    if (res.ok) {
      this.dispatch('refresh', { detail: { reason: 'deleted' } })
    }
  }

  async restoreClip() {
    if (!this.clipIdValue) return
    const res = await fetch('/api/clip/' + encodeURIComponent(this.clipIdValue), {
      method: 'DELETE'
    })
    if (res.ok) {
      this.dispatch('refresh', { detail: { reason: 'restored' } })
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

  setStatus(message) {
    this.saveStatusTarget.textContent = message
    if (message) {
      clearTimeout(this.statusTimeout)
      this.statusTimeout = setTimeout(() => {
        this.saveStatusTarget.textContent = ''
      }, 2000)
    }
  }
}
