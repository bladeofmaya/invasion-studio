export function moveBoundary(cuts, index, edge, value, duration) {
  const result = cuts.map(cut => ({ ...cut }))
  const cut = result[index]
  if (!cut || !Number.isFinite(value) || !Number.isFinite(duration)) return result
  if (edge === 'start') cut.start = Math.max(0, Math.min(value, cut.end - 0.1))
  if (edge === 'end') cut.end = Math.min(duration, Math.max(value, cut.start + 0.1))
  return result
}

export function skipCut(time, cuts) {
  for (const cut of [...cuts].sort((a, b) => a.start - b.start)) {
    if (time >= cut.start && time < cut.end) time = cut.end
  }
  return time
}

export function demoTimeline(duration) {
  if (!Number.isFinite(duration) || duration <= 0) return { cuts: [], markers: [] }
  return {
    cuts: [{ start: duration * 0.05, end: duration * 0.15 }, { start: duration * 0.7, end: duration * 0.8 }],
    markers: [
      { time: duration * 0.25, label: 'Demo: Phantom defeated' },
      { time: duration * 0.6, label: 'Demo: Host defeated' }
    ]
  }
}
