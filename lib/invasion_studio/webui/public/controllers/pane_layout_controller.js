import ApplicationController from './application_controller.js'

export default class extends ApplicationController {
  static targets = ['divider']

  connect() {
    this.share = 35
    this.update(this.share)
    this.fetchJson('/api/settings/interface').then(settings => {
      if (!this.changed) this.update(settings.library_width)
    }).catch(error => this.showError('Could not load pane size: ' + error.message))
  }

  update(share) {
    this.share = Math.max(25, Math.min(55, share))
    this.element.style.setProperty('--library-width', `${this.share}%`)
    this.dividerTarget.setAttribute('aria-valuenow', String(Math.round(this.share)))
    this.dividerTarget.setAttribute('aria-valuetext', `Library ${Math.round(this.share)} percent`)
  }

  save() {
    const width = this.share
    this.saving = (this.saving || Promise.resolve()).then(() => this.fetchJson('/api/settings/interface', {
      method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ library_width: width })
    })).catch(error => this.showError('Could not save pane size: ' + error.message))
  }

  start(event) {
    if (event.button !== 0) return
    event.preventDefault()
    this.dividerTarget.focus()
    this.dividerTarget.setPointerCapture(event.pointerId)
  }

  move(event) {
    if (!this.dividerTarget.hasPointerCapture(event.pointerId)) return
    const bounds = this.element.getBoundingClientRect()
    this.changed = true
    this.update((event.clientX - bounds.left) / bounds.width * 100)
  }

  stop(event) {
    if (this.dividerTarget.hasPointerCapture(event.pointerId)) {
      this.dividerTarget.releasePointerCapture(event.pointerId)
      this.save()
    }
  }

  keydown(event) {
    if (!['ArrowLeft', 'ArrowRight', 'Home'].includes(event.key)) return
    event.preventDefault()
    this.changed = true
    this.update(event.key === 'Home' ? 35 : this.share + (event.key === 'ArrowLeft' ? -2 : 2))
    this.save()
  }
}
