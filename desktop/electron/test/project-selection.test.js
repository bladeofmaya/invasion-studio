import assert from "node:assert/strict"
import { mkdir, mkdtemp, rm } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { selectProject, validateProjectPath } from "../src/project-selection.js"

test("open and create modes request only a native directory", async () => {
  const calls = []
  const dialog = {
    async showOpenDialog(options) {
      calls.push(options)
      return { canceled: false, filePaths: ["/projects/elden-ring"] }
    }
  }

  assert.equal(await selectProject(dialog, "open"), "/projects/elden-ring")
  assert.equal(await selectProject(dialog, "create"), "/projects/elden-ring")
  assert.deepEqual(calls[0].properties, ["openDirectory"])
  assert.deepEqual(calls[1].properties, ["openDirectory", "createDirectory"])
})

test("selection cancellation returns null", async () => {
  const dialog = { showOpenDialog: async () => ({ canceled: true, filePaths: [] }) }

  assert.equal(await selectProject(dialog, "open"), null)
})

test("project validation accepts directories and rejects files or missing paths", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "invasion-studio-project-"))
  const project = path.join(root, "project")
  await mkdir(project)

  try {
    assert.equal(await validateProjectPath(project), project)
    assert.equal(await validateProjectPath(path.join(root, "missing")), null)
    assert.equal(await validateProjectPath(""), null)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
