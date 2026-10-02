import '@videojs/html/video/player'
import '@videojs/html/video/skin'
import './player-prototype.css'
import { ClipPlayback } from './clip_playback.mjs'
import { demoTimeline, moveBoundary, skipCut } from './timeline_math.mjs'

const $ = id => document.getElementById(id)
const video = document.querySelector('video')
let clip, cuts = [], markers = [], history = [], start = null, dirty = false, busy = false
let audioTrack = 4
const status = text => { $('status').textContent = text }
const playback = new ClipPlayback(video, {
  onMetadata() {
    $('seek').max = video.duration
    $('editor').disabled = false
    render()
  },
  onLoaded() { status(playback.direct ? 'Original video · direct audio selection' : 'Remuxed preview') },
  onError() { status(`Video could not load (media error ${video.error?.code ?? 'unknown'}). Check Diagnostics in Settings.`) },
  onStatus: status
})

async function request(url, data) {
  const response = await fetch(url, data === undefined ? {} : {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
  })
  const result = await response.json()
  if (!response.ok) throw new Error(result.error || `Request failed (${response.status})`)
  return result
}

function remember() { history.push(structuredClone(cuts)) }
function changed() { dirty = true; render() }
function button(text, action) {
  const element = document.createElement('button')
  element.type = 'button'
  element.textContent = text
  element.addEventListener('click', action)
  return element
}

function render() {
  $('ranges').replaceChildren()
  $('markers').replaceChildren()
  $('cut-list').replaceChildren()
  $('event-list').replaceChildren()
  const duration = video.duration
  cuts.forEach((cut, index) => {
    const span = document.createElement('div')
    span.className = 'cut'
    span.style.left = `${cut.start / duration * 100}%`
    span.style.width = `${(cut.end - cut.start) / duration * 100}%`
    const row = document.createElement('div')
    row.className = 'cut-row'
    row.append(`Remove ${index + 1}: `)
    for (const edge of ['start', 'end']) {
      const handle = button('', () => {})
      handle.className = `handle ${edge}`
      handle.setAttribute('aria-label', `Drag cut ${index + 1} ${edge}; edit exact time below`)
      handle.tabIndex = -1
      handle.addEventListener('pointerdown', event => {
        if (busy) return
        event.preventDefault()
        remember()
        handle.setPointerCapture(event.pointerId)
        const update = move => {
          const rect = $('timeline').getBoundingClientRect()
          cuts = moveBoundary(cuts, index, edge, (move.clientX - rect.left) / rect.width * duration, duration)
          span.style.left = `${cuts[index].start / duration * 100}%`
          span.style.width = `${(cuts[index].end - cuts[index].start) / duration * 100}%`
          input.value = cuts[index][edge].toFixed(2)
          dirty = true
          $('draft').textContent = 'Unsaved cuts'
        }
        const end = () => {
          handle.removeEventListener('pointermove', update)
          handle.removeEventListener('lostpointercapture', end)
          render()
        }
        handle.addEventListener('pointermove', update)
        handle.addEventListener('lostpointercapture', end)
      })
      span.append(handle)
      const label = document.createElement('label')
      label.textContent = `${edge} (s) `
      const input = document.createElement('input')
      input.type = 'number'; input.min = 0; input.max = duration; input.step = 0.1
      input.value = cut[edge].toFixed(2)
      input.addEventListener('change', () => {
        remember()
        cuts = moveBoundary(cuts, index, edge, input.valueAsNumber, duration)
        changed()
      })
      label.append(input); row.append(label)
    }
    row.append(button('Delete range', () => { remember(); cuts.splice(index, 1); changed() }))
    $('ranges').append(span); $('cut-list').append(row)
  })
  markers.forEach((marker, index) => {
    const jump = () => { video.currentTime = marker.time }
    const pin = button('◆', jump)
    pin.className = 'marker'; pin.style.left = `${marker.time / duration * 100}%`
    pin.title = `${marker.label} · ${marker.time.toFixed(2)}s`
    pin.setAttribute('aria-label', pin.title)
    $('markers').append(pin)
    $('event-list').append(button(`${index + 1}. ${pin.title}`, jump))
  })
  $('draft').textContent = dirty ? 'Unsaved cuts' : ''
  $('undo').disabled = !history.length
  $('finalize').disabled = !cuts.length
}

async function loadClip(id, version = null) {
  $('editor').disabled = true
  playback.stop()
  clip = await request(`/api/clip/${encodeURIComponent(id)}`)
  cuts = structuredClone(clip.cuts || [])
  markers = []; history = []; start = null; dirty = false
  $('mark-start').textContent = '[ Mark start'
  playback.load(`/clip/${encodeURIComponent(clip.filename)}`, { track: audioTrack, version })
}

async function save() {
  await request('/api/cuts', { id: clip.id, cuts })
  dirty = false
  render()
}

// Serialize mutations and clip selection so an in-flight save/finalize cannot
// apply its result to a different selected clip.
async function perform(action) {
  if (busy) return
  busy = true
  $('clips').disabled = true; $('editor').disabled = true
  try { await action() } catch (error) { status(error.message) }
  finally { busy = false; $('clips').disabled = false; $('editor').disabled = !clip || !Number.isFinite(video.duration) }
}

$('clips').addEventListener('change', () => {
  const id = $('clips').value
  if (!id || (dirty && !confirm('Discard unsaved prototype cuts?'))) {
    $('clips').value = clip?.id || ''; return
  }
  perform(() => loadClip(id))
})
$('seek').addEventListener('input', () => { video.currentTime = Number($('seek').value) })
$('fullscreen').addEventListener('click', () => {
  const action = document.fullscreenElement ? document.exitFullscreen() : $('editor').requestFullscreen()
  action.catch(error => status(error.message))
})
$('demo').addEventListener('click', () => {
  if (cuts.length && !confirm('Replace the draft ranges with two demo cuts? Saved cuts stay unchanged until Save.')) return
  remember()
  const demo = demoTimeline(video.duration)
  cuts = demo.cuts
  markers = demo.markers
  changed()
})
$('mark-start').addEventListener('click', () => {
  start = video.currentTime
  $('mark-start').textContent = `[ Start: ${start.toFixed(2)}s`
})
$('mark-end').addEventListener('click', () => {
  if (start === null || video.currentTime <= start) { status('Mark a start, then seek or play forward before marking the end.'); return }
  remember(); cuts.push({ start, end: video.currentTime }); start = null
  $('mark-start').textContent = '[ Mark start'; changed()
})
$('undo').addEventListener('click', () => { if (history.length) { cuts = history.pop(); changed() } })
$('save').addEventListener('click', () => perform(save))
$('finalize').addEventListener('click', () => {
  if (!confirm('Save and finalize these removal ranges? This modifies the clip using the existing finalization workflow.')) return
  perform(async () => {
    video.pause()
    await save()
    status('Finalizing cuts…')
    await request(`/api/clip/${encodeURIComponent(clip.id)}/finalize`, {})
    await loadClip(clip.id, String(Date.now()))
  })
})
video.addEventListener('timeupdate', () => {
  if ($('skip').checked && !video.paused && !video.seeking) {
    const next = skipCut(video.currentTime, cuts)
    if (next > video.currentTime) video.currentTime = Math.min(next, video.duration)
  }
  $('seek').value = video.currentTime
  $('time').textContent = `${video.currentTime.toFixed(2)} / ${(video.duration || 0).toFixed(2)} s`
  $('playhead').style.left = `${video.currentTime / video.duration * 100}%`
})
window.addEventListener('beforeunload', event => {
  if (dirty || busy) { event.preventDefault(); event.returnValue = '' }
})

async function initialize() {
  const [clips, settings] = await Promise.all([request('/api/clips'), request('/api/settings/video')])
  audioTrack = settings.default_audio_track || 4
  $('audio').textContent = `Track ${audioTrack}`
  clips.forEach(item => $('clips').add(new Option(item.title || item.filename, item.id)))
  status(clips.length ? 'Select a clip to try the player.' : 'No clips yet. Import a recording first.')
}
initialize().catch(error => status(error.message))
