import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["videoWrapper", "controls", "audioTrack", "filename", "timeline", "cutList", "placeholder"]
  static values = {
    clipId: { type: String, default: "" },
    src: { type: String, default: "" },
    cuts: { type: Array, default: [] }
  }

  connect() {
    this.currentCutStart = null
    this.renderCuts()
  }

  clipIdValueChanged() {
    if (this.clipIdValue) {
      this.loadClip()
    } else {
      this.reset()
    }
  }

  cutsValueChanged() {
    this.renderCuts()
  }

  loadClip() {
    this.controlsTarget.style.display = 'flex'
    this.placeholderTarget.style.display = 'none'
    const audioTrack = this.audioTrackTarget.value
    const videoSrc = this.srcValue + '?audio_track=' + audioTrack
    this.videoWrapperTarget.innerHTML = '<video src="' + videoSrc + '" controls></video>'
    const video = this.videoWrapperTarget.querySelector('video')
    if (video) {
      video.addEventListener('loadedmetadata', () => this.renderCuts())
    }
  }

  reset() {
    this.controlsTarget.style.display = 'none'
    this.placeholderTarget.style.display = 'flex'
    this.videoWrapperTarget.innerHTML = '<div class="text-text-muted text-sm">Select a clip to preview</div>'
    this.timelineTarget.innerHTML = ''
    this.cutListTarget.innerHTML = ''
    this.currentCutStart = null
  }

  changeAudioTrack() {
    const video = this.videoWrapperTarget.querySelector('video')
    const currentTime = video ? video.currentTime : 0
    this.loadClip()
    const newVideo = this.videoWrapperTarget.querySelector('video')
    if (newVideo) {
      newVideo.currentTime = currentTime
    }
  }

  async openFile() {
    if (!this.clipIdValue) return
    const res = await fetch('/api/clip/' + encodeURIComponent(this.clipIdValue) + '/open', {
      method: 'POST'
    })
    if (!res.ok) {
      const data = await res.json()
      alert('Could not open file: ' + (data.error || 'Unknown error'))
    }
  }

  markCutStart() {
    const video = this.videoWrapperTarget.querySelector('video')
    if (!video) return
    this.currentCutStart = video.currentTime
    this.dispatchStatus('Cut start: ' + this.formatTime(this.currentCutStart))
  }

  markCutEnd() {
    if (this.currentCutStart === null) {
      alert('Press [ Mark first to set a start point')
      return
    }
    const video = this.videoWrapperTarget.querySelector('video')
    if (!video) return
    const end = video.currentTime
    if (end <= this.currentCutStart) {
      alert('End time must be after start time')
      return
    }
    this.cutsValue = [...this.cutsValue, { start: this.currentCutStart, end: end }]
    this.currentCutStart = null
    this.saveCuts()
  }

  clearCuts() {
    if (!confirm('Clear all cuts?')) return
    this.cutsValue = []
    this.currentCutStart = null
    this.saveCuts()
  }

  deleteCut(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.cutsValue = this.cutsValue.filter((_, i) => i !== index)
    this.saveCuts()
  }

  async saveCuts() {
    if (!this.clipIdValue) return
    const res = await fetch('/api/cuts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: this.clipIdValue, cuts: this.cutsValue })
    })
    if (res.ok) {
      this.dispatchStatus('Cuts saved')
    } else {
      this.dispatchStatus('Error saving cuts')
    }
  }

  renderCuts() {
    const cuts = this.cutsValue
    const video = this.videoWrapperTarget.querySelector('video')
    const duration = video ? video.duration : 0

    if (duration > 0) {
      this.timelineTarget.innerHTML = ''
      if (cuts && cuts.length > 0) {
        cuts.forEach(cut => {
          const left = (cut.start / duration) * 100
          const width = ((cut.end - cut.start) / duration) * 100
          const div = document.createElement('div')
          div.className = 'absolute h-full bg-danger/60 rounded-sm'
          div.style.left = left + '%'
          div.style.width = width + '%'
          div.title = this.formatTime(cut.start) + ' - ' + this.formatTime(cut.end)
          this.timelineTarget.appendChild(div)
        })
      }
    } else {
      this.timelineTarget.innerHTML = '<div style="font-size:0.75rem; color:var(--text-muted); padding:2px 6px;">Play video to see timeline</div>'
    }

    this.cutListTarget.innerHTML = ''
    if (cuts && cuts.length > 0) {
      cuts.forEach((cut, index) => {
        const item = document.createElement('span')
        item.className = 'inline-flex items-center gap-1'
        item.innerHTML = 'Cut ' + (index + 1) + ': ' + this.formatTime(cut.start) + ' - ' + this.formatTime(cut.end) +
          ' <button data-action="click->video-player#deleteCut" data-index="' + index + '">x</button>'
        this.cutListTarget.appendChild(item)
      })
    } else {
      this.cutListTarget.innerHTML = '<span style="opacity:0.5">No cuts defined</span>'
    }
  }

  dispatchStatus(message) {
    this.element.dispatchEvent(new CustomEvent('status', { detail: { message }, bubbles: true }))
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    const ms = Math.floor((seconds % 1) * 100)
    return m + ':' + (s < 10 ? '0' : '') + s + '.' + (ms < 10 ? '0' : '') + ms
  }
}
