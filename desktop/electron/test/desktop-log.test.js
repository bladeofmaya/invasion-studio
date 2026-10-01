import assert from 'node:assert/strict'
import test from 'node:test'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { DesktopLog } from '../src/desktop-log.js'

test('desktop diagnostics persist with timestamps and bounded rotation', () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'invasion-log-'))
  try {
    const log = new DesktopLog(path.join(directory, 'desktop.log'), { maxBytes: 100 })
    log.write('backend', 'first error'.repeat(20))
    log.write('renderer', 'decoder failed')
    const latest = JSON.parse(readFileSync(log.path, 'utf8'))
    assert.equal(latest.source, 'renderer')
    assert.equal(latest.message, 'decoder failed')
    assert.ok(Date.parse(latest.time))
    assert.match(readFileSync(`${log.path}.1`, 'utf8'), /first error/)
  } finally {
    rmSync(directory, { recursive: true, force: true })
  }
})
