import assert from "node:assert/strict"
import test from "node:test"

import { isAllowedAppUrl, isAllowedExternalUrl } from "../src/security.js"

test("application navigation is restricted to the exact sidecar origin", () => {
  assert.equal(isAllowedAppUrl("http://127.0.0.1:49152/", 49152), true)
  assert.equal(isAllowedAppUrl("http://127.0.0.1:49152/api/health", 49152), true)
  assert.equal(isAllowedAppUrl("http://localhost:49152/", 49152), false)
  assert.equal(isAllowedAppUrl("http://127.0.0.1:49153/", 49152), false)
  assert.equal(isAllowedAppUrl("https://127.0.0.1:49152/", 49152), false)
  assert.equal(isAllowedAppUrl("http://127.0.0.1:49152.evil.example/", 49152), false)
  assert.equal(isAllowedAppUrl("not a url", 49152), false)
})

test("only HTTPS links may be handed to the system browser", () => {
  assert.equal(isAllowedExternalUrl("https://bladeofmaya.com/about"), true)
  assert.equal(isAllowedExternalUrl("http://bladeofmaya.com/about"), false)
  assert.equal(isAllowedExternalUrl("file:///etc/passwd"), false)
  assert.equal(isAllowedExternalUrl("javascript:alert(1)"), false)
})
