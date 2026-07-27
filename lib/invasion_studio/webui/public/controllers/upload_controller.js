import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["input", "hint"]

  connect() {
    this.onDragOver = (event) => this.preventDefault(event)
    this.onDrop = (event) => this.preventDefault(event)
    document.addEventListener('dragover', this.onDragOver)
    document.addEventListener('drop', this.onDrop)
  }

  disconnect() {
    document.removeEventListener('dragover', this.onDragOver)
    document.removeEventListener('drop', this.onDrop)
  }

  preventDefault(event) {
    event.preventDefault()
  }

  trigger(event) {
    if (event.target === this.inputTarget) return
    event?.preventDefault()
    this.inputTarget.click()
  }

  selected(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.uploadFiles(files)
    }
    this.inputTarget.value = ''
  }

  async uploadFiles(files) {
    const formData = new FormData()
    // Rack only collects repeated fields into an array when the name ends
    // in []; a plain repeated 'files' key keeps just the last file.
    Array.from(files).forEach(file => formData.append('files[]', file))

    this.showHint(`Uploading ${files.length} clip(s)...`)

    try {
      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData
      })

      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Upload failed')
      }

      this.showHint(`Uploaded ${data.imported} clip(s).`)
      this.dispatch('complete')
    } catch (err) {
      this.showHint(`Upload failed: ${err.message}`)
      this.dispatch('error', { detail: { error: err.message } })
    }

    setTimeout(() => {
      this.hideHint()
    }, 3000)
  }

  showHint(message) {
    if (!this.hasHintTarget) return
    this.hintTarget.textContent = message
    this.hintTarget.classList.remove('hidden')
  }

  hideHint() {
    if (!this.hasHintTarget) return
    this.hintTarget.classList.add('hidden')
    this.hintTarget.textContent = ''
  }
}
