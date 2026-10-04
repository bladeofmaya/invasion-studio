import { renderIcons } from './icons.js'

// Media controls share the editor's toolbar and native HTMLMediaElement.
export class PlaybackControls {
  constructor(root, video) {
    this.video = video
    this.events = new AbortController()
    this.element = document.createElement('div')
    this.element.className = 'playback-controls'
    this.playButton = this.button(() => this.togglePlay())
    this.muteButton = this.button(() => { video.muted = !video.muted })
    this.volume = document.createElement('input')
    this.volume.type = 'range'
    this.volume.min = '0'; this.volume.max = '1'; this.volume.step = '0.05'
    this.volume.setAttribute('aria-label', 'Volume')
    this.volume.addEventListener('input', () => {
      video.volume = Number(this.volume.value)
      video.muted = video.volume === 0
    })
    this.status = document.createElement('span')
    this.status.className = 'playback-control-status'
    this.status.setAttribute('role', 'status')
    this.element.append(this.playButton, this.muteButton, this.volume, this.status)
    root.prepend(this.element)
    const options = { signal: this.events.signal }
    for (const name of ['play', 'pause', 'ended', 'volumechange', 'loadedmetadata']) {
      video.addEventListener(name, () => this.update(), options)
    }
    for (const name of ['waiting', 'seeking']) {
      video.addEventListener(name, () => { this.status.textContent = name === 'seeking' ? 'Seeking…' : 'Buffering…' }, options)
    }
    for (const name of ['playing', 'canplay', 'seeked', 'pause', 'ended']) {
      video.addEventListener(name, () => { this.status.textContent = '' }, options)
    }
    video.addEventListener('error', () => { this.status.textContent = 'Playback unavailable' }, options)
    video.tabIndex = 0
    video.setAttribute('aria-label', 'Video preview. Space to play or pause; arrow keys to seek; M to mute.')
    video.addEventListener('click', () => this.togglePlay(), options)
    video.addEventListener('keydown', event => this.keydown(event), options)
    this.update()
  }

  button(action) {
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'playback-icon-button'
    button.addEventListener('click', action)
    return button
  }

  label(button, text, iconName) {
    button.setAttribute('aria-label', text)
    button.title = text
    const icon = document.createElement('i')
    icon.dataset.lucide = iconName
    icon.setAttribute('aria-hidden', 'true')
    button.replaceChildren(icon)
  }

  update() {
    const muted = this.video.muted || this.video.volume === 0
    this.label(this.playButton, this.video.paused ? 'Play' : 'Pause', this.video.paused ? 'play' : 'pause')
    this.label(this.muteButton, muted ? 'Unmute' : 'Mute', muted ? 'volume-x' : 'volume-2')
    this.muteButton.setAttribute('aria-pressed', String(muted))
    this.volume.value = this.video.muted ? 0 : this.video.volume
    this.volume.setAttribute('aria-valuetext', `${Math.round(Number(this.volume.value) * 100)}%`)
    renderIcons(this.element)
  }

  async togglePlay() {
    if (!this.video.paused) { this.video.pause(); return }
    try {
      await this.video.play()
      if (!this.events.signal.aborted) this.status.textContent = ''
    } catch (error) {
      if (!this.events.signal.aborted && error.name !== 'AbortError') this.status.textContent = 'Could not play. Try again.'
    }
  }

  keydown(event) {
    // Native buttons/ranges retain their own keyboard behavior.
    const onVideo = event.target === this.video
    const onTimeline = event.target.getAttribute('role') === 'slider'
    if ((!onVideo && !onTimeline) || event.altKey || event.ctrlKey || event.metaKey || event.repeat) return
    if (event.code === 'Space' || event.key.toLowerCase() === 'k') {
      event.preventDefault(); void this.togglePlay()
    } else if (event.key.toLowerCase() === 'm') {
      event.preventDefault(); this.video.muted = !this.video.muted
    } else if (onVideo && ['ArrowLeft', 'ArrowRight'].includes(event.key) && Number.isFinite(this.video.duration)) {
      event.preventDefault()
      this.video.currentTime = Math.max(0, Math.min(this.video.duration, this.video.currentTime + (event.key === 'ArrowLeft' ? -5 : 5)))
    }
  }

  destroy() { this.events.abort(); this.element.remove() }
}
