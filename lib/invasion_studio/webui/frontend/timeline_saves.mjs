// Serialize snapshots, retaining failed edits for retry even after selection moves.
export class TimelineSaves {
  constructor(write, onState = () => {}) {
    this.write = write
    this.onState = onState
    this.tail = Promise.resolve()
    this.failed = new Map()
    this.pending = 0
  }

  get hasUnsaved() { return this.pending > 0 || this.failed.size > 0 }

  save(id, kind, values) {
    const snapshot = structuredClone(values)
    const key = JSON.stringify([id, kind])
    this.pending++
    this.tail = this.tail.then(async () => {
      try {
        await this.write(id, kind, snapshot)
        this.failed.delete(key)
        this.onState(id, kind, null, snapshot)
      } catch (error) {
        this.failed.set(key, { id, kind, values: snapshot })
        this.onState(id, kind, error, snapshot)
      } finally { this.pending-- }
    })
    return this.tail
  }

  async flush(id) {
    // Include edits enqueued while an earlier snapshot was being written.
    let pending
    do { pending = this.tail; await pending } while (pending !== this.tail)
    return ![...this.failed.values()].some(entry => entry.id === id)
  }

  async retry(id) {
    await this.tail
    for (const entry of this.failed.values()) {
      if (entry.id === id) this.save(entry.id, entry.kind, entry.values)
    }
    return this.flush(id)
  }
}
