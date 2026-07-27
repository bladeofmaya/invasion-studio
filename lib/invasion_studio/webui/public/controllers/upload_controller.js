import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["input", "overlay", "progressBar", "progressStatus", "closeBtn"]

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

    this.openOverlay()

    try {
      const data = await this.uploadWithProgress(formData, files.length)
      this.setProgress(100)
      // Files are stored; unlock Close and refresh the list before the
      // (potentially slow) thumbnail generation finishes.
      this.closeBtnTarget.disabled = false
      this.dispatch('complete')

      const done = await this.waitForThumbnails(data.clips)
      this.dispatch('complete')
      this.setStatus(done
        ? `Uploaded ${data.imported} clip(s).`
        : `Uploaded ${data.imported} clip(s). Thumbnails are still generating in the background.`)
    } catch (err) {
      this.setStatus(`Upload failed: ${err.message}`)
      this.dispatch('error', { detail: { error: err.message } })
    } finally {
      this.closeBtnTarget.disabled = false
    }
  }

  uploadWithProgress(formData, count) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest()
      xhr.open('POST', '/api/upload')
      xhr.responseType = 'json'
      xhr.upload.addEventListener('progress', (event) => {
        if (!event.lengthComputable) return
        const percent = Math.round((event.loaded / event.total) * 100)
        this.setProgress(percent)
        this.setStatus(`Uploading ${count} clip(s)... ${percent}%`)
      })
      xhr.addEventListener('load', () => {
        const data = xhr.response
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(data)
        } else {
          reject(new Error(data?.error || 'Upload failed'))
        }
      })
      xhr.addEventListener('error', () => reject(new Error('Network error')))
      xhr.send(formData)
    })
  }

  // Polls until every uploaded clip has a thumbnail. Returns false when it
  // gives up (generation continues server-side either way).
  async waitForThumbnails(clipIds) {
    const deadline = Date.now() + 120000
    while (Date.now() < deadline) {
      if (this.overlayTarget.style.display === 'none') return false
      const missing = await this.countMissingThumbnails(clipIds)
      if (missing === 0) return true
      this.setStatus(`Generating thumbnails... (${clipIds.length - missing}/${clipIds.length})`)
      await new Promise(resolve => setTimeout(resolve, 1000))
    }
    return false
  }

  async countMissingThumbnails(clipIds) {
    const clips = await Promise.all(clipIds.map(id =>
      this.fetchJson('/api/clip/' + encodeURIComponent(id)).catch(() => null)
    ))
    return clips.filter(clip => !clip || !clip.thumbnail_url).length
  }

  openOverlay() {
    this.closeBtnTarget.disabled = true
    this.setProgress(0)
    this.setStatus('Preparing...')
    this.overlayTarget.style.display = 'flex'
  }

  closeOverlay() {
    this.overlayTarget.style.display = 'none'
  }

  setProgress(percent) {
    this.progressBarTarget.style.width = percent + '%'
  }

  setStatus(message) {
    this.progressStatusTarget.textContent = message
  }
}
