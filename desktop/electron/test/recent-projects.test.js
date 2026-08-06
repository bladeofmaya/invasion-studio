import assert from "node:assert/strict"
import { mkdir, mkdtemp, readFile, rm } from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import test from "node:test"

import { RecentProjects } from "../src/recent-projects.js"

test("recent projects are newest-first, deduplicated, and persisted", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "invasion-studio-recents-"))
  const first = path.join(root, "first")
  const second = path.join(root, "second")
  await mkdir(first)
  await mkdir(second)
  const filePath = path.join(root, "recent-projects.json")
  const recents = new RecentProjects({ filePath, clock: sequenceClock() })

  try {
    await recents.add(first)
    await recents.add(second)
    await recents.add(first)

    assert.deepEqual(await recents.list(), [
      { path: first, name: "first", lastOpenedAt: "2026-08-06T12:00:02.000Z" },
      { path: second, name: "second", lastOpenedAt: "2026-08-06T12:00:01.000Z" }
    ])
    assert.equal(JSON.parse(await readFile(filePath, "utf8")).length, 2)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test("recent projects prunes missing folders and enforces its limit", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "invasion-studio-recents-"))
  const filePath = path.join(root, "recent-projects.json")
  const recents = new RecentProjects({ filePath, limit: 2, clock: sequenceClock() })
  const projects = ["one", "two", "three"].map(name => path.join(root, name))

  try {
    for (const project of projects) {
      await mkdir(project)
      await recents.add(project)
    }
    await rm(projects[2], { recursive: true })

    assert.deepEqual((await recents.list()).map(project => project.path), [projects[1]])
    assert.deepEqual(JSON.parse(await readFile(filePath, "utf8")).map(project => project.path), [projects[1]])
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

function sequenceClock() {
  let second = 0
  return () => new Date(`2026-08-06T12:00:0${second++}.000Z`)
}
