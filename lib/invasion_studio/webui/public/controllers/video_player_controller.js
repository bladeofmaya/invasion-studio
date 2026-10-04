import { ClipPlayback } from '../../frontend/clip_playback.mjs'
import { ClipTimeline } from '../../frontend/clip_timeline.mjs'
import { TimelineSaves } from '../../frontend/timeline_saves.mjs'
import ApplicationController from './application_controller.js'

export default class extends ApplicationController {
  static targets = ['videoWrapper', 'controls', 'timelineEditor', 'timelineDetails', 'playerShell', 'placeholder', 'playbackStatus', 'saveError', 'markerStatus']
  static values = { clipId: String, src: String, cuts: Array }

  initialize() {
    this.loadSequence = 0
    this.saves = new TimelineSaves(async (id, kind, values) => {
      await this.fetchJson(`/api/${kind}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, [kind]: values })
      })
    }, (id, kind, error, values) => {
      this.saveErrorTarget.hidden = !this.saves.failed.size
      if (error) return
      if (kind === 'cuts') this.dispatch('cuts-saved', { detail: { clipId: id, hasCuts: values.length > 0 } })
    })
  }

  connect() {
    this.videoSettingsChanged = event => this.applyVideoSettings(event.detail)
    document.addEventListener('video-settings:changed', this.videoSettingsChanged)
    this.beforeUnload = event => {
      if (this.saves.hasUnsaved || this.identification?.status === 'running') { event.preventDefault(); event.returnValue = '' }
    }
    window.addEventListener('beforeunload', this.beforeUnload)
    this.loadVideoSettings()
    this.identificationTimer = setInterval(() => this.pollMarkerIdentification(), 1500)
  }

  disconnect() {
    document.removeEventListener('video-settings:changed', this.videoSettingsChanged)
    window.removeEventListener('beforeunload', this.beforeUnload)
    clearInterval(this.identificationTimer)
    this.reset()
  }

  async loadVideoSettings() {
    try { this.applyVideoSettings(await this.fetchJson('/api/settings/video')) }
    catch { this.applyVideoSettings({ audio_track_count: 4, default_audio_track: 4 }) }
  }

  applyVideoSettings(settings) {
    this.defaultAudioTrack = settings.default_audio_track
    if (this.clipIdValue) this.loadClip()
  }

  clipIdValueChanged() {
    this.mediaVersion = null
    if (this.clipIdValue) this.loadClip()
    else this.reset()
  }

  async loadClip() {
    if (!this.defaultAudioTrack) return
    const id = this.clipIdValue
    this.reset()
    const sequence = this.loadSequence
    this.placeholderTarget.style.display = 'none'
    this.setStatus('Loading clip…')
    try {
      if (!await this.saves.flush(id)) {
        this.setStatus('This clip has unsaved timeline edits. Retry saving before reopening it.')
        return
      }
      const clip = await this.fetchJson('/api/clip/' + encodeURIComponent(id))
      if (sequence !== this.loadSequence || id !== this.clipIdValue) return
      this.controlsTargets.forEach(element => { element.style.display = 'flex' })
      this.videoWrapperTarget.innerHTML = '<video-player><video playsinline preload="metadata"></video></video-player>'
      const video = this.videoWrapperTarget.querySelector('video')
      this.timeline = new ClipTimeline(this.timelineEditorTarget, video, {
        cuts: clip.cuts, markers: clip.markers, audioTrack: this.defaultAudioTrack,
        detailsRoot: this.timelineDetailsTarget,
        onChange: (kind, values) => this.saves.save(id, kind, values),
        onFinalize: () => this.editorController?.finalizeCuts(),
        onIdentify: () => this.identifyMarkers()
      })
      this.playback = new ClipPlayback(video, {
        onMetadata: () => { this.timeline.disabled = this.editorController?.finalizingClipId === id || this.identificationRunning(id) },
        onLoaded: () => { this.playbackStatusTarget.hidden = true },
        onError: video => this.showPlaybackError(video),
        onStatus: message => this.setStatus(message)
      })
      this.playback.load('/clip/' + encodeURIComponent(clip.filename), {
        track: this.defaultAudioTrack,
        version: this.mediaVersion
      })
      this.pollMarkerIdentification()
    } catch (error) {
      if (sequence === this.loadSequence) this.setStatus(`Could not load clip: ${error.message}`)
    }
  }

  get editorController() {
    return this.application.getControllerForElementAndIdentifier(this.element.querySelector('[data-controller~="editor"]'), 'editor')
  }

  setStatus(message) {
    this.playbackStatusTarget.hidden = false
    this.playbackStatusTarget.textContent = message
  }

  showPlaybackError(video) {
    const reasons = { 1: 'Playback was interrupted.', 2: 'The video could not be downloaded.',
      3: 'The player could not decode this video.', 4: 'This video format is not supported, or the source is unavailable.' }
    this.playbackStatusTarget.hidden = false
    this.playbackStatusTarget.textContent = reasons[video.error?.code] || 'The video could not be loaded.'
    console.error('Preview playback failed', JSON.stringify({
      code: video.error?.code, message: video.error?.message, src: video.currentSrc,
      readyState: video.readyState, networkState: video.networkState
    }))
  }

  async retrySaves() {
    const ids = new Set([...this.saves.failed.values()].map(entry => entry.id))
    for (const id of ids) await this.saves.retry(id)
    if (!this.timeline && this.clipIdValue && !this.saves.failed.size) this.loadClip()
  }

  identificationRunning(id) {
    return this.identification?.status === 'running' && this.identification.clip_id === id
  }

  async identifyMarkers() {
    const id = this.clipIdValue
    if (!id || !this.timeline || this.identification?.status === 'running' || this.startingIdentification) return
    this.startingIdentification = true
    this.timeline.disabled = true
    try {
      if (!await this.saves.flush(id)) throw new Error('Retry saving your edits before identifying markers.')
      if (id !== this.clipIdValue) return
      this.identification = await this.fetchJson(`/api/clip/${encodeURIComponent(id)}/identify-markers`, { method: 'POST' })
      await this.showIdentificationStatus(this.identification)
    } catch (error) {
      if (id === this.clipIdValue) {
        this.markerStatusTarget.hidden = false
        this.markerStatusTarget.textContent = `Could not identify markers: ${error.message}`
      }
    } finally {
      this.startingIdentification = false
      if (id === this.clipIdValue && this.timeline && !this.identificationRunning(id)) this.timeline.disabled = false
    }
  }

  async pollMarkerIdentification() {
    if (!this.clipIdValue || !this.timeline || this.pollingIdentification || this.startingIdentification) return
    this.pollingIdentification = true
    try {
      const state = await this.fetchJson('/api/marker-identification')
      if (this.startingIdentification || !this.element.isConnected) return
      this.identification = state
      await this.showIdentificationStatus(state)
    } catch (error) {
      if (this.identificationRunning(this.clipIdValue)) {
        this.markerStatusTarget.textContent = 'Waiting for marker scan status…'
      }
    } finally { this.pollingIdentification = false }
  }

  async showIdentificationStatus(state) {
    if (!this.timeline) return
    const id = this.clipIdValue
    this.timeline.identifyButton.disabled = state.status === 'running'
    if (state.status === 'idle') return
    if (state.clip_id !== id) { this.markerStatusTarget.hidden = true; return }
    this.markerStatusTarget.hidden = false
    if (state.status === 'running') {
      this.timeline.disabled = true
      this.markerStatusTarget.textContent = state.total
        ? `Identifying markers… ${state.current || 0} / ${state.total} frames. Keep the app open.`
        : 'Identifying markers… reading video frames. Keep the app open.'
    } else {
      if (state.status === 'completed' && this.lastIdentificationId !== state.id) {
        this.timeline.disabled = true
        if (!await this.saves.flush(id)) return
        const clip = await this.fetchJson('/api/clip/' + encodeURIComponent(id))
        if (id !== this.clipIdValue || !this.timeline) return
        this.timeline.markers = clip.markers || []
        // Pre-scan undo snapshots must not erase newly detected events.
        this.timeline.history = this.timeline.history.filter(entry => entry.kind !== 'markers')
        this.timeline.render()
        this.lastIdentificationId = state.id
      }
      if (this.timeline) this.timeline.disabled = this.editorController?.finalizingClipId === id
      this.markerStatusTarget.textContent = state.status === 'completed'
        ? `Marker scan complete: ${state.added} new ${state.added === 1 ? 'marker' : 'markers'}.`
        : `Marker scan failed: ${state.error}`
    }
  }

  async prepareFinalize(id) {
    if (id !== this.clipIdValue || !this.timeline) return false
    this.timeline.disabled = true
    this.playback.video.pause()
    const saved = await this.saves.flush(id)
    if (!saved) {
      this.timeline.disabled = false
      this.setStatus('Could not save timeline edits. Retry saving before finalizing.')
    }
    return saved && id === this.clipIdValue
  }

  finishFinalize() { if (this.timeline) this.timeline.disabled = false }

  reloadFinalizedClip(event) {
    if (event.detail.clipId !== this.clipIdValue) return
    this.mediaVersion = Date.now().toString()
    this.loadClip()
  }

  reset() {
    this.loadSequence++
    this.timeline?.destroy()
    this.timeline = null
    this.playback?.stop()
    this.playback = null
    this.playbackStatusTarget.hidden = true
    this.controlsTargets.forEach(element => { element.style.display = 'none' })
    this.markerStatusTarget.hidden = true
    this.placeholderTarget.style.display = 'flex'
    this.videoWrapperTarget.innerHTML = '<div class="text-text-muted text-sm">Select a clip to preview</div>'
  }


  async fullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen()
      else await this.playerShellTarget.requestFullscreen()
    } catch (error) { this.showError(error.message) }
  }

  async revealFile() {
    if (!this.clipIdValue) return
    try { await this.fetchJson('/api/clip/' + encodeURIComponent(this.clipIdValue) + '/reveal', { method: 'POST' }) }
    catch (error) { this.showError('Could not reveal file: ' + error.message) }
  }
}
