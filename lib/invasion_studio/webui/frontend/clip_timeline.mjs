import { moveBoundary, skipCut } from './timeline_math.mjs'
import { renderIcons } from './icons.js'
import { PlaybackControls } from './playback_controls.mjs'

export const EVENT_TYPES = {
  custom: 'Custom', phantom_defeated: 'Phantom defeated', hunter_defeated: 'Hunter defeated', host_defeated: 'Host defeated',
  invasion_start: 'Invasion start', invasion_end: 'Invasion end'
}

function element(tag, text, className) {
  const node = document.createElement(tag)
  if (text) node.textContent = text
  if (className) node.className = className
  return node
}

function button(text, action, className, iconName) {
  const node = element('button', text, className)
  if (iconName) setActionLabel(node, text, iconName)
  node.type = 'button'
  node.addEventListener('click', action)
  return node
}

function setActionLabel(node, text, iconName) {
  const icon = element('i', null, 'timeline-action-icon')
  icon.dataset.lucide = iconName
  icon.setAttribute('aria-hidden', 'true')
  node.classList.add('timeline-action')
  node.replaceChildren(icon, element('span', text))
}

// Owns the editable timeline, independent of Stimulus and persistence.
export class ClipTimeline {
  constructor(root, video, { cuts = [], markers = [], audioTrack = null, detailsRoot = null, onChange, onFinalize, onIdentify = () => {} }) {
    this.root = root
    this.video = video
    this.cuts = structuredClone(cuts)
    this.markers = structuredClone(markers)
    this.onChange = onChange
    this.history = []
    this.events = new AbortController()
    this.field = element('fieldset', null, 'clip-timeline-editor')
    this.field.disabled = true
    this.detailsField = element('fieldset', null, 'clip-timeline-editor')
    this.detailsField.disabled = true
    this.toolbar = element('div', null, 'timeline-toolbar')
    this.startButton = button('Start cut', () => this.toggleCut(), null, 'scissors')
    this.cancelButton = button('Cancel cut', () => this.cancelCut())
    this.undoButton = button('Undo', () => this.undo(), null, 'undo-2')
    this.finalizeButton = button('Finalize cuts…', onFinalize)
    this.addMarkerButton = button('Add marker', () => {
      this.remember('markers')
      this.markers.push({ id: crypto.randomUUID(), time: video.currentTime, event_type: 'custom', label: '' })
      this.commit('markers')
    }, null, 'map-pin-plus')
    this.identifyButton = button('Identify markers', onIdentify, null, 'scan-text')
    const previewButton = button('Use current frame as preview', () => {}, 'timeline-preview-button', 'image')
    previewButton.dataset.action = 'click->video-player#capturePreview'
    this.identifyButton.title = 'Scan this clip for phantom and hunter defeat messages'
    const editActions = element('div', null, 'timeline-edit-actions')
    editActions.setAttribute('role', 'group')
    editActions.setAttribute('aria-label', 'Edit clip')
    editActions.append(this.startButton, this.cancelButton, this.addMarkerButton, this.identifyButton, this.undoButton, previewButton)
    this.toolbar.append(editActions)
    const skipLabel = element('label', null, 'timeline-toggle')
    this.skip = document.createElement('input')
    this.skip.type = 'checkbox'; this.skip.checked = true
    skipLabel.append(this.skip, ' Preview without cuts')
    this.skipLabel = skipLabel
    this.track = element('div', null, 'clip-timeline-track')
    this.track.setAttribute('aria-label', 'Event markers and removal ranges')
    this.spans = element('div')
    this.pins = element('div')
    this.playhead = element('div', null, 'timeline-playhead')
    this.track.append(this.spans, this.pins, this.playhead)
    this.track.setAttribute('role', 'slider')
    this.track.setAttribute('aria-label', 'Seek video')
    this.track.setAttribute('aria-valuemin', '0')
    this.track.tabIndex = 0
    this.track.addEventListener('keydown', event => {
      this.seekKey(event)
      this.playbackControls.keydown(event)
    })
    this.track.addEventListener('pointerdown', event => {
      if (this.field.disabled || event.button !== 0 || event.target.closest('button')) return
      event.preventDefault()
      this.track.focus()
      this.track.setPointerCapture(event.pointerId)
      this.seekAt(event.clientX)
    })
    this.track.addEventListener('pointermove', event => {
      if (this.track.hasPointerCapture(event.pointerId)) this.seekAt(event.clientX)
    })
    this.track.addEventListener('pointerup', event => {
      if (this.track.hasPointerCapture(event.pointerId)) this.track.releasePointerCapture(event.pointerId)
    })
    this.clock = element('output', null, 'timeline-clock')
    this.toolbar.append(this.clock)
    this.playbackControls = new PlaybackControls(this.toolbar, video)
    this.cutList = element('div', null, 'timeline-rows')
    this.markerList = element('div', null, 'timeline-rows')
    this.message = element('div', null, 'timeline-message')
    this.message.setAttribute('role', 'status')
    this.cutPanel = element('section', null, 'timeline-cut-panel')
    this.cutPanel.setAttribute('aria-label', 'Cuts and markers')
    const fullscreenButton = element('button', null, 'clip-fullscreen-button')
    fullscreenButton.type = 'button'
    fullscreenButton.title = 'Fullscreen editor'
    fullscreenButton.setAttribute('aria-label', 'Fullscreen editor')
    fullscreenButton.dataset.action = 'click->video-player#fullscreen'
    setActionLabel(fullscreenButton, 'Fullscreen editor', 'maximize')
    const headingActions = element('div', null, 'timeline-player-actions')
    const audioLabel = element('span', `Audio: ${audioTrack == null ? '—' : `Track ${audioTrack}`}`, 'clip-audio-label')
    audioLabel.title = 'Selected in Settings'
    headingActions.append(audioLabel, fullscreenButton)
    this.toolbar.append(headingActions)
    this.cutSection = element('section', null, 'timeline-cut-section')
    this.cutSection.setAttribute('aria-label', 'Removal ranges')
    const cutHeading = element('div', null, 'timeline-section-heading')
    cutHeading.append(element('h3', 'Cuts to remove'), this.finalizeButton)
    this.cutSection.append(cutHeading, this.cutList, skipLabel)
    const markerSection = element('section', null, 'timeline-marker-section')
    markerSection.setAttribute('aria-label', 'Event markers')
    markerSection.append(element('h3', 'Markers'), this.markerList)
    this.markerSection = markerSection
    this.help = element('p', 'Seek to a moment, then start a cut or add a marker.', 'timeline-help')
    const playerFooter = element('div', null, 'timeline-player-footer')
    playerFooter.setAttribute('role', 'group')
    playerFooter.setAttribute('aria-label', 'Seek and edit video')
    playerFooter.append(this.track, this.toolbar, this.message)
    this.cutPanel.append(this.help, this.cutSection, markerSection)
    this.field.append(playerFooter)
    this.detailsField.append(this.cutPanel)
    root.replaceChildren(this.field)
    if (detailsRoot) detailsRoot.replaceChildren(this.detailsField)
    else root.append(this.detailsField)
    video.addEventListener('loadedmetadata', () => this.ready(), { signal: this.events.signal })
    video.addEventListener('timeupdate', () => this.tick(), { signal: this.events.signal })
    this.render()
    if (Number.isFinite(video.duration) && video.duration > 0) this.ready()
  }

  ready() {
    this.disabled = false
    this.track.setAttribute('aria-valuemax', this.video.duration)
    this.render()
    this.tick()
  }

  destroy() { this.events.abort(); this.playbackControls.destroy(); this.detailsField.remove(); this.root.replaceChildren() }
  set disabled(value) {
    this.field.disabled = value
    this.detailsField.disabled = value
    this.track.setAttribute('aria-disabled', String(value))
    this.track.tabIndex = value ? -1 : 0
  }

  seekTo(time) {
    if (this.field.disabled || !Number.isFinite(this.video.duration) || this.video.duration <= 0) return
    this.video.currentTime = Math.max(0, Math.min(this.video.duration, time))
    this.tick()
  }

  seekAt(clientX) {
    const rect = this.track.getBoundingClientRect()
    if (rect.width > 0) this.seekTo((clientX - rect.left) / rect.width * this.video.duration)
  }

  seekKey(event) {
    const time = this.video.currentTime
    const times = { ArrowLeft: time - 1, ArrowRight: time + 1, ArrowDown: time - 1,
      ArrowUp: time + 1, Home: 0, End: this.video.duration }
    if (!(event.key in times)) return
    event.preventDefault()
    this.seekTo(times[event.key])
  }
  remember(kind) { this.history.push({ kind, values: structuredClone(this[kind]) }) }
  commit(kind) { this.render(); this.onChange(kind, structuredClone(this[kind])) }
  undo() {
    const previous = this.history.pop()
    if (!previous) return
    this[previous.kind] = previous.values
    this.commit(previous.kind)
  }

  addCut() {
    if (this.start == null || this.video.currentTime <= this.start) {
      this.message.textContent = 'Seek or play forward from the cut start, then choose End cut here.'
      return
    }
    this.remember('cuts')
    this.cuts.push({ start: this.start, end: this.video.currentTime })
    this.start = null
    this.message.textContent = ''
    this.commit('cuts')
  }

  toggleCut() {
    if (this.start != null) return this.addCut()
    this.start = this.video.currentTime
    this.message.textContent = `Cut starts at ${this.start.toFixed(2)}s. Seek forward, then choose End cut here.`
    this.render()
  }

  cancelCut() {
    this.start = null
    this.message.textContent = ''
    this.render()
  }

  tick() {
    const video = this.video
    if (this.skip.checked && !video.paused && !video.seeking) {
      const next = skipCut(video.currentTime, this.cuts)
      if (next > video.currentTime) video.currentTime = Math.min(next, video.duration)
    }
    this.track.setAttribute('aria-valuenow', video.currentTime.toFixed(2))
    this.clock.textContent = `${video.currentTime.toFixed(2)} / ${(video.duration || 0).toFixed(2)} s`
    this.track.setAttribute('aria-valuetext', this.clock.textContent)
    this.playhead.style.left = `${video.currentTime / video.duration * 100}%`
  }

  eventSelect(value) {
    const select = document.createElement('select')
    Object.entries(EVENT_TYPES).forEach(([key, label]) => select.add(new Option(label, key)))
    select.value = value
    return select
  }

  timeInput(label, value, update) {
    const wrapper = element('label', `${label} (s) `)
    const input = document.createElement('input')
    input.type = 'number'; input.min = 0; input.max = this.video.duration || 0; input.step = 0.01
    input.value = value.toFixed(2)
    input.addEventListener('change', () => {
      if (Number.isFinite(input.valueAsNumber)) {
        const adjusted = update(input.valueAsNumber)
        if (Number.isFinite(adjusted)) input.value = adjusted.toFixed(2)
      }
      else input.value = value.toFixed(2)
    })
    wrapper.append(input)
    return wrapper
  }

  drag(node, kind, update) {
    node.addEventListener('pointerdown', event => {
      if (this.field.disabled || event.button !== 0) return
      event.preventDefault()
      const original = structuredClone(this[kind])
      let moved = false
      node.setPointerCapture(event.pointerId)
      const move = event => {
        if (Math.abs(event.clientX - startX) < 3 && !moved) return
        moved = true
        const rect = this.track.getBoundingClientRect()
        const time = Math.max(0, Math.min(this.video.duration, (event.clientX - rect.left) / rect.width * this.video.duration))
        update(time)
      }
      const startX = event.clientX
      const finish = () => {
        node.removeEventListener('pointermove', move)
        node.removeEventListener('lostpointercapture', finish)
        if (!moved) return
        this.history.push({ kind, values: original })
        this.commit(kind)
      }
      node.addEventListener('pointermove', move)
      node.addEventListener('lostpointercapture', finish)
    })
  }

  render() {
    this.spans.replaceChildren(); this.pins.replaceChildren()
    this.cutList.replaceChildren(); this.markerList.replaceChildren()
    const duration = this.video.duration
    const ready = Number.isFinite(duration) && duration > 0
    setActionLabel(this.startButton, this.start == null ? 'Start cut' : 'End cut here', 'scissors')
    this.cancelButton.hidden = this.start == null
    this.undoButton.hidden = !this.history.length
    this.finalizeButton.hidden = !this.cuts.length
    this.cutSection.hidden = !this.cuts.length
    this.markerSection.hidden = !this.markers.length
    this.help.hidden = this.start != null || this.cuts.length > 0 || this.markers.length > 0
    this.undoButton.disabled = !this.history.length
    this.finalizeButton.disabled = !this.cuts.length
    this.cuts.forEach((cut, index) => {
      const span = element('div', null, 'timeline-cut')
      const position = () => {
        span.style.left = `${this.cuts[index].start / duration * 100}%`
        span.style.width = `${(this.cuts[index].end - this.cuts[index].start) / duration * 100}%`
      }
      if (ready) position()
      const row = element('div', `Cut ${index + 1}`, 'timeline-row')
      for (const edge of ['start', 'end']) {
        const handle = button('', () => {}, `timeline-handle ${edge}`)
        handle.tabIndex = -1
        handle.setAttribute('aria-label', `Drag cut ${index + 1} ${edge}; exact time available below`)
        this.drag(handle, 'cuts', time => {
          this.cuts = moveBoundary(this.cuts, index, edge, time, duration)
          position()
        })
        span.append(handle)
        row.append(this.timeInput(edge, cut[edge], value => {
          this.remember('cuts')
          this.cuts = moveBoundary(this.cuts, index, edge, value, duration)
          position()
          this.undoButton.disabled = false
          this.undoButton.hidden = false
          this.onChange('cuts', structuredClone(this.cuts))
          return this.cuts[index][edge]
        }))
      }
      row.append(button('Delete', () => {
        this.remember('cuts'); this.cuts.splice(index, 1); this.commit('cuts')
      }))
      if (ready) this.spans.append(span)
      this.cutList.append(row)
    })
    const sortedMarkers = [...this.markers].sort((a, b) => a.time - b.time)
    sortedMarkers.forEach(marker => {
      const jump = () => { this.video.currentTime = marker.time }
      const pin = button('◆', jump, 'timeline-marker')
      pin.style.left = `${marker.time / duration * 100}%`
      pin.title = `${EVENT_TYPES[marker.event_type]}${marker.label ? ': ' + marker.label : ''} · ${marker.time.toFixed(2)}s`
      pin.setAttribute('aria-label', pin.title)
      this.drag(pin, 'markers', time => { marker.time = time; pin.style.left = `${time / duration * 100}%` })
      if (ready) this.pins.append(pin)
      const row = element('div', null, 'timeline-row')
      const update = (field, value) => {
        this.remember('markers')
        marker[field] = value
        pin.style.left = `${marker.time / duration * 100}%`
        pin.title = `${EVENT_TYPES[marker.event_type]}${marker.label ? ': ' + marker.label : ''} · ${marker.time.toFixed(2)}s`
        pin.setAttribute('aria-label', pin.title)
        this.undoButton.disabled = false
        this.undoButton.hidden = false
        this.onChange('markers', structuredClone(this.markers))
        return value
      }
      const type = this.eventSelect(marker.event_type)
      type.setAttribute('aria-label', 'Marker event type')
      type.addEventListener('change', () => update('event_type', type.value))
      const label = document.createElement('input')
      label.type = 'text'; label.value = marker.label; label.maxLength = 500
      label.placeholder = 'Optional label'; label.setAttribute('aria-label', 'Marker label')
      label.addEventListener('change', () => update('label', label.value))
      row.append(button('Jump', jump, null, 'corner-down-right'), this.timeInput('Time', marker.time, value => update('time', Math.max(0, Math.min(duration, value)))), type, label,
        button('Delete', () => {
          this.remember('markers'); this.markers = this.markers.filter(item => item.id !== marker.id); this.commit('markers')
        }))
      this.markerList.append(row)
    })
    renderIcons(this.field)
    renderIcons(this.detailsField)
  }
}
