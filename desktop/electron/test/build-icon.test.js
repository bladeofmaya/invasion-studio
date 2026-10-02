import assert from "node:assert/strict"
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import { spawnSync } from "node:child_process"
import test from "node:test"

test("icon generation preserves the source and pads rectangular artwork with transparency", {
  skip: spawnSync("magick", ["-version"]).status !== 0 ? "ImageMagick is not installed" : false
}, () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "studio icon "))
  const run = (command, args) => {
    const result = spawnSync(command, args, { cwd: os.tmpdir(), encoding: "utf8" })
    assert.equal(result.status, 0, result.stderr)
    return result.stdout
  }
  try {
    mkdirSync(path.join(root, "bin"))
    const assets = path.join(root, "desktop/electron/assets")
    mkdirSync(assets, { recursive: true })
    copyFileSync(new URL("../../../bin/build-icon", import.meta.url), path.join(root, "bin/build-icon"))
    const source = path.join(assets, "logo.png")
    run("magick", ["-size", "800x400", "xc:red", source])
    const original = readFileSync(source)
    run("bash", [path.join(root, "bin/build-icon")])
    assert.deepEqual(readFileSync(source), original)
    assert.deepEqual(readFileSync(path.join(assets, "app-icon-master.png")), original)
    assert.equal(run("magick", [path.join(assets, "app-icon.png"), "-format",
      "%wx%h %[fx:p{0,0}.a] %[fx:p{256,256}.r] %[fx:p{256,256}.a]", "info:"]),
      "512x512 0 1 1")
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})
