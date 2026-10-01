// Owns one media element's source and track selection. Direct playback leaves
// seeking and A/V synchronization to the browser's media pipeline.
export class ClipPlayback {
  constructor(video, { onMetadata = () => {}, onLoaded = () => {}, onError = () => {}, onStatus = () => {} } = {}) {
    this.video = video
    this.onMetadata = onMetadata
    this.onLoaded = onLoaded
    this.onError = onError
    this.onStatus = onStatus
  }

  load(source, { track = 1, version = null, restore = null, remux = false } = {}) {
    this.events?.abort()
    this.events = new AbortController()
    this.source = source
    this.track = track
    this.version = version
    this.restore = restore
    this.metadataLoaded = false
    this.direct = !remux && 'audioTracks' in this.video
    const params = new URLSearchParams()
    if (!this.direct) params.set('audio_track', track)
    if (version) params.set('version', version)
    const url = source + (params.size ? '?' + params.toString() : '')
    const options = { signal: this.events.signal }

    this.video.addEventListener('loadedmetadata', () => {
      this.metadataLoaded = true
      if (this.direct && !this.applyTrack()) {
        this.fallback()
        return
      }
      this.onMetadata()
      const state = this.restore
      this.restore = null
      if (state) {
        this.video.currentTime = state.time
        if (!state.paused) {
          this.video.play().catch(error => {
            if (!options.signal.aborted) this.onStatus(`Press Play to resume: ${error.message}`)
          })
        }
      }
    }, options)
    this.video.addEventListener('loadeddata', () => this.onLoaded(), options)
    this.video.addEventListener('error', () => this.onError(this.video), options)
    this.onStatus(this.direct ? 'Loading original video…' : 'Preparing preview…')
    console.info('Loading preview', url, this.direct ? '(direct)' : '(remux)')
    this.video.src = url
    this.video.load()
  }

  selectTrack(track) {
    this.track = track
    if (this.direct) {
      // Metadata may still be loading. Its handler will apply the latest choice.
      if (!this.metadataLoaded || this.applyTrack()) return
      this.fallback()
    } else {
      this.reloadRemux()
    }
  }

  applyTrack() {
    const tracks = this.video.audioTracks
    const index = this.track - 1
    if (!Number.isInteger(index) || index < 0 || index >= tracks.length) return false
    try {
      tracks[index].enabled = true
      for (let i = 0; i < tracks.length; i++) {
        if (i !== index) tracks[i].enabled = false
      }
      return Array.from(tracks).every((track, i) => track.enabled === (i === index))
    } catch (error) {
      console.warn('Direct audio-track selection failed:', error.message)
      return false
    }
  }

  fallback() {
    console.warn(`Audio track ${this.track} cannot be selected directly; using a remuxed preview`)
    this.reloadRemux()
  }

  reloadRemux() {
    const restore = this.restore || { time: this.video.currentTime, paused: this.video.paused }
    this.load(this.source, { track: this.track, version: this.version, remux: true, restore })
  }

  stop() {
    this.events?.abort()
    this.restore = null
    this.video.pause()
    this.video.removeAttribute('src')
    this.video.load()
  }
}
