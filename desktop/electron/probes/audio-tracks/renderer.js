import { describeAudioTracks, selectAudioTrack } from './selection.js'

const video = document.querySelector('#video')
const picker = document.querySelector('#file')
const selector = document.querySelector('#tracks')
const status = document.querySelector('#status')
const diagnostics = document.querySelector('#diagnostics')
let sourceUrl
let selectedAt
const entries = []

function record(event, extra = {}) {
  const entry = {
    event, time: video.currentTime, paused: video.paused,
    readyState: video.readyState, networkState: video.networkState,
    tracks: describeAudioTracks(video), ...extra
  }
  entries.push(entry)
  if (entries.length > 100) entries.shift()
  diagnostics.value = entries.map(item => JSON.stringify(item)).join('\n')
  diagnostics.scrollTop = diagnostics.scrollHeight
  console.log(JSON.stringify(entry))
}

function refreshTracks() {
  const tracks = describeAudioTracks(video)
  selector.replaceChildren(...tracks.map(track => new Option(
    `Track ${track.index + 1}${track.label ? ` — ${track.label}` : ''}${track.language ? ` (${track.language})` : ''}`,
    String(track.index), false, track.enabled
  )))
  selector.disabled = tracks.length === 0
}

const supported = 'audioTracks' in video
status.textContent = supported ? 'Audio-track API available. Select a recording to inspect its tracks.' : 'Audio-track API unavailable in this Electron configuration.'
record('capability', { supported, userAgent: navigator.userAgent })

picker.addEventListener('change', () => {
  const file = picker.files[0]
  if (!file) return
  video.pause()
  video.removeAttribute('src')
  video.load()
  if (sourceUrl) URL.revokeObjectURL(sourceUrl)
  sourceUrl = URL.createObjectURL(file)
  selectedAt = performance.now()
  selector.disabled = true
  status.textContent = 'Reading metadata from the original file…'
  video.src = sourceUrl
  record('file-selected', { filename: file.name, bytes: file.size })
})

video.addEventListener('loadedmetadata', () => {
  refreshTracks()
  status.textContent = `${video.audioTracks?.length || 0} audio track(s) found. Press Play, then choose each track.`
  record('loadedmetadata', { elapsedMs: Math.round(performance.now() - selectedAt), duration: video.duration })
})

for (const name of ['loadeddata', 'playing', 'pause', 'waiting', 'stalled', 'seeking', 'seeked', 'ended']) {
  video.addEventListener(name, () => record(name))
}
video.addEventListener('error', () => {
  status.textContent = `Playback error ${video.error?.code}: ${video.error?.message}`
  record('error', { code: video.error?.code, message: video.error?.message })
})
video.audioTracks?.addEventListener('addtrack', refreshTracks)
video.audioTracks?.addEventListener('change', () => { refreshTracks(); record('tracks-changed') })
selector.addEventListener('change', () => {
  try {
    const index = Number(selector.value)
    selectAudioTrack(video, index)
    status.textContent = `Requested track ${index + 1}. Listen to confirm the correct audio and sync.`
    record('track-requested', { index, sourceUnchanged: video.src === sourceUrl })
  } catch (error) {
    status.textContent = error.message
  }
})
