import assert from "node:assert/strict"
import test from "node:test"

import { WindowHandoff } from "../src/window-handoff.js"

test("launcher remains alive while the application window is starting", () => {
  const events = []
  const launcher = {
    hide: () => events.push("launcher hidden"),
    destroy: () => events.push("launcher destroyed")
  }
  const handoff = new WindowHandoff(launcher)

  handoff.begin()

  assert.deepEqual(events, ["launcher hidden"])
})

test("launcher is destroyed only after an application window exists", () => {
  const events = []
  const launcher = {
    hide: () => events.push("launcher hidden"),
    destroy: () => events.push("launcher destroyed")
  }
  const handoff = new WindowHandoff(launcher)

  handoff.begin()
  handoff.complete({})

  assert.deepEqual(events, ["launcher hidden", "launcher destroyed"])
})

test("handoff refuses to destroy the last window", () => {
  const launcher = { hide() {}, destroy() { throw new Error("must not destroy") } }
  const handoff = new WindowHandoff(launcher)

  assert.throws(() => handoff.complete(null), /application window is required/)
})
