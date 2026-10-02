import assert from "node:assert/strict"
import test from "node:test"
import { configurePermissions } from "../src/permissions.js"

test("fullscreen is allowed only for the application window and its main frame", () => {
  const origin = "http://127.0.0.1:49152"
  const contents = { getURL: () => `${origin}/`, isDestroyed: () => false }
  const handlers = {}
  configurePermissions({
    setPermissionRequestHandler: handler => { handlers.request = handler },
    setPermissionCheckHandler: handler => { handlers.check = handler }
  }, contents, 49152)

  const cases = [
    [contents, "fullscreen", origin, true, true],
    [contents, "media", origin, true, false],
    [contents, "notifications", origin, true, false],
    [contents, "fullscreen", "https://example.com", true, false],
    [contents, "fullscreen", "http://127.0.0.1:49153", true, false],
    [contents, "fullscreen", origin, false, false],
    [{ ...contents }, "fullscreen", origin, true, false],
    [null, "fullscreen", origin, true, false]
  ]
  for (const [sender, permission, requestingUrl, isMainFrame, expected] of cases) {
    const details = { requestingUrl, isMainFrame }
    assert.equal(handlers.check(sender, permission, requestingUrl, details), expected)
    let result
    handlers.request(sender, permission, granted => { result = granted }, details)
    assert.equal(result, expected)
  }
  contents.getURL = () => "https://example.com"
  assert.equal(handlers.check(contents, "fullscreen", origin, { isMainFrame: true }), false)
})
