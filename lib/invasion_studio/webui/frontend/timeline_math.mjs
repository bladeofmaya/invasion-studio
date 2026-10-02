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
