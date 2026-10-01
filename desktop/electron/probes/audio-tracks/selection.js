export function describeAudioTracks(video) {
  return Array.from(video.audioTracks || [], (track, index) => ({
    index, id: track.id, label: track.label, language: track.language, enabled: track.enabled
  }))
}

export function selectAudioTrack(video, index) {
  const tracks = video.audioTracks
  if (!tracks || !Number.isInteger(index) || index < 0 || index >= tracks.length) {
    throw new Error('The requested audio track is unavailable')
  }
  tracks[index].enabled = true
  for (let i = 0; i < tracks.length; i++) {
    if (i !== index) tracks[i].enabled = false
  }
}
