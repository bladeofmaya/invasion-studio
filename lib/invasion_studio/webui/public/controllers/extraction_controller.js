import ApplicationController from './application_controller.js'

export default class extends ApplicationController {
  static targets = ['paths', 'picker', 'fields', 'threads', 'workers', 'fps', 'padStart', 'padEnd', 'hwaccel', 'noCache', 'status', 'progress', 'viewClips']

  connect() {
    this.connected = true
    this.pickerTarget.hidden = !window.invasionStudioImport?.chooseRecordings
    this.poll()
  }

  disconnect() {
    this.connected = false
    clearTimeout(this.timer)
  }

  async chooseRecordings() {
    try {
      const paths = await window.invasionStudioImport.chooseRecordings()
      if (paths) this.pathsTarget.value = paths.join('\n')
    } catch (error) {
      this.showError(error.message)
    }
  }

  async start(event) {
    event.preventDefault()
    if (this.fieldsTarget.disabled) return
    this.fieldsTarget.disabled = true
    clearTimeout(this.timer)
    // Invalidate any earlier status request that might finish after this POST.
    this.requestVersion = (this.requestVersion || 0) + 1
    try {
      const state = await this.fetchJson('/api/extraction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          paths: this.pathsTarget.value.split('\n').map(path => path.trim()).filter(Boolean),
          options: {
            ffmpeg_threads: Number(this.threadsTarget.value),
            ocr_workers: Number(this.workersTarget.value),
            fps: Number(this.fpsTarget.value),
            pad_start: Number(this.padStartTarget.value),
            pad_end: Number(this.padEndTarget.value),
            hwaccel: this.hwaccelTarget.checked,
            no_cache: this.noCacheTarget.checked
          }
        })
      })
      this.renderStatus(state)
    } catch (error) {
      this.statusTarget.textContent = error.message
      this.showError(error.message)
      // Refresh before enabling another start: a lost response may still mean
      // the server accepted the job, or another window started it first.
    }
    this.schedulePoll()
  }

  async poll() {
    const version = this.requestVersion = (this.requestVersion || 0) + 1
    try {
      const state = await this.fetchJson('/api/extraction')
      if (this.connected && version === this.requestVersion) this.renderStatus(state)
    } catch (error) {
      if (this.connected && version === this.requestVersion) {
        this.fieldsTarget.disabled = true
        this.statusTarget.textContent = `Cannot check extraction status: ${error.message}. Retrying…`
      }
    } finally {
      if (version === this.requestVersion) this.schedulePoll()
    }
  }

  schedulePoll() {
    if (this.connected) this.timer = setTimeout(() => this.poll(), 1500)
  }

  renderStatus(state) {
    const running = state.status === 'running'
    this.fieldsTarget.disabled = running
    this.progressTarget.hidden = !running
    this.viewClipsTarget.hidden = !(state.imported > 0)
    if (state.total > 0 && Number.isFinite(state.current)) {
      this.progressTarget.max = state.total
      this.progressTarget.value = state.current
    } else {
      this.progressTarget.removeAttribute('value')
    }

    const stages = { starting: 'Preparing extraction', ocr: 'Reading recording', scanning: 'Finding invasions', extracting: 'Extracting clips' }
    let message = 'Ready to extract recordings.'
    if (running) {
      message = stages[state.stage] || 'Extracting'
      if (state.file) message += `: ${state.file}`
      if (state.total > 0) message += ` (${state.current || 0}/${state.total})`
    } else if (state.status === 'completed') {
      message = state.imported > 0 ? `Imported ${state.imported} clip(s). Thumbnails are generated in the background.` : 'No invasions detected. No clips were added.'
    } else if (state.status === 'failed') {
      message = `Extraction failed: ${state.error}. ${state.imported || 0} clip(s) were saved.`
    }
    this.statusTarget.textContent = message

    if (!running && state.id && this.completedId !== state.id) {
      this.completedId = state.id
      document.dispatchEvent(new CustomEvent('upload:complete'))
    }
  }

  viewClips() {
    this.navigateTo({ view: 'all', group: '', filter: 'everything', sort: 'newest', q: '', tag: '', rating: '', result: '', clipId: '' })
  }
}
