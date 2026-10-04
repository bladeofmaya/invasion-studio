import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, rmSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const command = fileURLToPath(new URL('../../script/dev.mjs', import.meta.url))
// Only exercise argument handling: never launch an app, build assets or touch media.
test('dev help works outside the repository without starting anything', () => {
  const result = spawnSync(process.execPath, [command, '--help'], { cwd: os.tmpdir(), encoding: 'utf8' })
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stdout, /--browser/)
  assert.match(result.stdout, /no packaging/)
})

test('dev rejects ambiguous or unsupported arguments before launching processes', () => {
  for (const args of [['--unknown'], ['one', 'two']]) {
    const result = spawnSync(process.execPath, [command, ...args], { encoding: 'utf8' })
    assert.equal(result.status, 2)
    assert.match(result.stderr, /Usage:/)
  }
})

test('dev resolves project paths against the original caller directory', () => {
  const caller = mkdtempSync(path.join(os.tmpdir(), 'studio caller '))
  try {
    const result = spawnSync(process.execPath, [command, '--browser', 'missing-project'], {
      cwd: os.tmpdir(), encoding: 'utf8', env: { ...process.env, STUDIO_CALLER_DIR: caller }
    })
    assert.notEqual(result.status, 0)
    assert.ok(result.stderr.includes(path.join(caller, 'missing-project')))
  } finally {
    rmSync(caller, { recursive: true, force: true })
  }
})
