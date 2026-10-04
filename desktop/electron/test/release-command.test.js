import assert from "node:assert/strict"
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import { spawnSync } from "node:child_process"
import test from "node:test"

for (const buildStatus of [0, 1]) {
  test(`release --install ${buildStatus ? "stops after a failed build" : "assembles before installing"}`, () => {
    const root = mkdtempSync(path.join(os.tmpdir(), "studio release "))
    try {
      for (const dir of ["bin", "script"]) mkdirSync(path.join(root, dir))
      for (const file of ["bin/release", "script/environment"]) {
        copyFileSync(new URL(`../../../${file}`, import.meta.url), path.join(root, file))
      }
      for (const name of ["build-icon", "build-desktop", "prepare-release"]) {
        writeFileSync(path.join(root, "script", name),
          `#!/bin/sh\necho ${name} >> "$CALL_LOG"\nexit ${name === "build-desktop" ? buildStatus : 0}\n`, { mode: 0o755 })
      }
      writeFileSync(path.join(root, "bin/flatpak"),
        '#!/bin/sh\necho installed >> "$CALL_LOG"\n', { mode: 0o755 })
      const artifact = path.join(root, "desktop/electron/out/make/flatpak/x86_64/com.bladeofmaya.InvasionStudio_stable_x86_64.flatpak")
      mkdirSync(path.dirname(artifact), { recursive: true })
      writeFileSync(artifact, "fixture")
      const log = path.join(root, "calls")
      const result = spawnSync("bash", [path.join(root, "bin/release"), "--install"], {
        cwd: os.tmpdir(), encoding: "utf8",
        env: { ...process.env, STUDIO_TOOLCHAIN_ACTIVE: "1", PATH: `${root}/bin:${process.env.PATH}`, CALL_LOG: log }
      })
      assert.equal(result.status, buildStatus, result.stderr)
      assert.equal(readFileSync(log, "utf8"), buildStatus
        ? "build-icon\nbuild-desktop\n"
        : "build-icon\nbuild-desktop\nprepare-release\ninstalled\n")
    } finally {
      rmSync(root, { recursive: true, force: true })
    }
  })
}
