// Rack rejects multipart request bodies above 10 GiB. Leave room for
// multipart overhead and send large selections as sequential requests.
export const MAX_BATCH_BYTES = 8 * 1024 * 1024 * 1024

export function partitionUploadBatches(files) {
  const batches = []
  let batch = []
  let batchBytes = 0

  files.forEach(file => {
    if (batch.length > 0 && batchBytes + file.size > MAX_BATCH_BYTES) {
      batches.push(batch)
      batch = []
      batchBytes = 0
    }
    batch.push(file)
    batchBytes += file.size
  })
  if (batch.length > 0) batches.push(batch)

  return batches
}

export function uploadProgressPercent({ uploadedBytes, loaded, total, batchBytes, totalBytes }) {
  if (totalBytes <= 0) return 100

  const batchLoaded = total > 0
    ? Math.min(loaded / total, 1) * batchBytes
    : Math.min(loaded, batchBytes)
  const percent = Math.round(((uploadedBytes + batchLoaded) / totalBytes) * 100)
  return Math.max(0, Math.min(percent, 99))
}
