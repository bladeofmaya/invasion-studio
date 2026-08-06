import assert from "node:assert/strict"
import { mkdtemp, rm } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import test from "node:test"

import { buildSidecarArgs, Sidecar, parseReadyLine } from "../src/sidecar.js"

const currentDirectory = path.dirname(fileURLToPath(import.meta.url))
const fixture = path.join(currentDirectory, "fixtures", "fake-sidecar.js")

test("parseReadyLine accepts only a valid readiness event", () => {
  assert.deepEqual(parseReadyLine('{"event":"ready","port":49152}'), {
    event: "ready",
    port: 49152
  })
  assert.equal(parseReadyLine("sidecar diagnostic"), null)
  assert.equal(parseReadyLine('{"event":"other","port":49152}'), null)
  assert.equal(parseReadyLine('{"event":"ready","port":0}'), null)
  assert.equal(parseReadyLine('{"event":"ready","port":70000}'), null)
})

test("buildSidecarArgs follows the packaged WebUI lifecycle contract", () => {
  assert.deepEqual(buildSidecarArgs({ projectPath: "/projects/elden-ring", parentPid: 42 }), [
    "--quiet",
    "webui",
    "--port",
    "0",
    "--parent-pid",
    "42",
    "/projects/elden-ring"
  ])
})

test("Sidecar starts, verifies health, and stops the child cleanly", async () => {
  const projectPath = await mkdtemp(path.join(os.tmpdir(), "invasion-studio-electron-"))
  const sidecar = new Sidecar({ timeoutMs: 2_000, stopTimeoutMs: 2_000 })

  try {
    const ready = await sidecar.start({
      executable: process.execPath,
      prefixArgs: [fixture],
      projectPath
    })

    assert.equal(ready.origin, `http://127.0.0.1:${ready.port}`)
    assert.equal(sidecar.running, true)

    await sidecar.stop()
    assert.equal(sidecar.running, false)
  } finally {
    await sidecar.stop()
    await rm(projectPath, { recursive: true, force: true })
  }
})

test("Sidecar times out with a useful error when readiness never arrives", async () => {
  const projectPath = await mkdtemp(path.join(os.tmpdir(), "invasion-studio-electron-"))
  const sidecar = new Sidecar({ timeoutMs: 100, stopTimeoutMs: 500 })

  try {
    await assert.rejects(
      sidecar.start({
        executable: process.execPath,
        prefixArgs: [fixture],
        projectPath,
        env: { ...process.env, FAKE_SIDECAR_MODE: "silent" }
      }),
      /did not become ready within 100ms/
    )
  } finally {
    await sidecar.stop()
    await rm(projectPath, { recursive: true, force: true })
  }
})

test("Sidecar includes stdout diagnostics when the backend exits before readiness", async () => {
  const projectPath = await mkdtemp(path.join(os.tmpdir(), "invasion-studio-electron-"))
  const sidecar = new Sidecar({ timeoutMs: 2_000, stopTimeoutMs: 500 })

  try {
    await assert.rejects(
      sidecar.start({
        executable: process.execPath,
        prefixArgs: [fixture],
        projectPath,
        env: { ...process.env, FAKE_SIDECAR_MODE: "failure" }
      }),
      /database migration mismatch/
    )
  } finally {
    await sidecar.stop()
    await rm(projectPath, { recursive: true, force: true })
  }
})
