import assert from "node:assert/strict"
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import { spawnSync } from "node:child_process"
import test from "node:test"

const script = new URL("../../../bin/install-desktop", import.meta.url)

for (const buildStatus of [0, 1]) {
  test(`desktop installer ${buildStatus ? "stops when the build fails" : "builds before reinstalling from any directory"}`, () => {
    const root = mkdtempSync(path.join(os.tmpdir(), "studio install "))
    try {
      mkdirSync(path.join(root, "bin"))
      copyFileSync(script, path.join(root, "bin/install-desktop"))
      writeFileSync(path.join(root, "bin/build-desktop"),
        `#!/bin/sh\nprintf 'build %s\\n' "$*" >> "$CALL_LOG"\nexit ${buildStatus}\n`, { mode: 0o755 })
      writeFileSync(path.join(root, "bin/flatpak"),
        '#!/bin/sh\nprintf "flatpak %s\\n" "$*" >> "$CALL_LOG"\n', { mode: 0o755 })
      const artifact = path.join(root, "desktop/electron/out/make/flatpak/x86_64/com.bladeofmaya.InvasionStudio_stable_x86_64.flatpak")
      mkdirSync(path.dirname(artifact), { recursive: true })
      writeFileSync(artifact, "")
      const log = path.join(root, "calls")
      const result = spawnSync("bash", [path.join(root, "bin/install-desktop")], {
        cwd: os.tmpdir(),
        env: { ...process.env, PATH: `${root}/bin:${process.env.PATH}`, CALL_LOG: log },
        encoding: "utf8"
      })
      assert.equal(result.status, buildStatus, result.stderr)
      assert.equal(readFileSync(log, "utf8"), buildStatus
        ? "build --make\n"
        : `build --make\nflatpak install --user --reinstall --noninteractive ${artifact}\n`)
    } finally {
      rmSync(root, { recursive: true, force: true })
    }
  })
}
