import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import test from 'node:test'

// Fake runners prove dispatch without running nested suites or processing media.
for (const [args, expected] of [
  [[], 'bundle exec rake test\nnpm test\nnpm test --prefix desktop/electron\n'],
  [['--browser'], 'npm run build\nnode script/check-browser\n'],
  [['--video'], 'bundle exec rake test:system\n'],
  [['--packaged'], 'node script/check-desktop\n'],
  [['--installed'], 'node script/check-desktop --flatpak\n'],
  [['--media-package'], 'bundle exec ruby script/smoke-test-tebako\n']
]) {
  test(`test dispatcher ${args.join(' ') || 'default'} selects only the requested checks`, () => {
    const root = mkdtempSync(path.join(os.tmpdir(), 'studio test dispatch '))
    try {
      for (const directory of ['bin', 'script', 'fake']) mkdirSync(path.join(root, directory))
      for (const file of ['bin/test', 'script/environment']) {
        copyFileSync(new URL(`../../${file}`, import.meta.url), path.join(root, file))
      }
      for (const runner of ['bundle', 'npm', 'node']) {
        writeFileSync(path.join(root, 'fake', runner),
          `#!/bin/sh\nprintf '${runner} %s\\n' "$*" >> "$CALL_LOG"\n`, { mode: 0o755 })
      }
      const log = path.join(root, 'calls')
      const result = spawnSync('bash', [path.join(root, 'bin/test'), ...args], {
        cwd: os.tmpdir(), encoding: 'utf8',
        env: { ...process.env, STUDIO_TOOLCHAIN_ACTIVE: '1', PATH: `${root}/fake:${process.env.PATH}`, CALL_LOG: log }
      })
      assert.equal(result.status, 0, result.stderr)
      assert.equal(readFileSync(log, 'utf8'), expected)
    } finally {
      rmSync(root, { recursive: true, force: true })
    }
  })
}
