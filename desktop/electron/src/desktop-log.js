import { appendFileSync, existsSync, mkdirSync, renameSync, statSync } from 'node:fs'
import path from 'node:path'

export class DesktopLog {
  constructor(filePath, { maxBytes = 2 * 1024 * 1024 } = {}) {
    this.path = filePath
    this.maxBytes = maxBytes
  }

  write(source, message) {
    try {
      mkdirSync(path.dirname(this.path), { recursive: true })
      if (existsSync(this.path) && statSync(this.path).size >= this.maxBytes) {
        renameSync(this.path, `${this.path}.1`)
      }
      appendFileSync(this.path, JSON.stringify({
        time: new Date().toISOString(), source, message: String(message).slice(-65536)
      }) + '\n', { mode: 0o600 })
    } catch (error) {
      // A full disk or unavailable log directory must not break playback.
      console.error('Could not write desktop log:', error.message)
    }
  }
}
