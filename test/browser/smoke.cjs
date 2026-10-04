const { app, BrowserWindow } = require('electron')
const { spawn } = require('node:child_process')
const { mkdtempSync, rmSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { join } = require('node:path')
const { createInterface } = require('node:readline')
const assert = require('node:assert/strict')
const root = mkdtempSync(join(tmpdir(), 'studio-browser-'))
app.setPath('userData', join(root, 'profile'))
let backend, window
const errors = []
let finishing = false
const deadline = setTimeout(() => { console.error('Browser smoke timed out'); finish(1) }, 45000)
async function finish(code) {
  if (finishing) return
  finishing = true
  clearTimeout(deadline)
  if (backend && backend.exitCode === null) {
    const exited = new Promise(resolve => backend.once('exit', resolve))
    backend.kill('SIGTERM')
    const force = setTimeout(() => backend.kill('SIGKILL'), 3000)
    await exited
    clearTimeout(force)
  }
  window?.destroy()
  rmSync(root, { recursive: true, force: true })
  app.exit(code)
}
process.on('SIGTERM', () => finish(1))
process.on('SIGINT', () => finish(1))
async function run() {
  await app.whenReady()
  backend = spawn('bundle', ['exec', 'ruby', '-Ilib', 'test/support/browser_fixture.rb', join(root, 'project')], { stdio: ['ignore', 'pipe', 'pipe'] })
  backend.stderr.on('data', chunk => process.stderr.write(chunk))
  const port = await new Promise((resolve, reject) => {
    backend.on('error', reject)
    backend.on('exit', code => reject(new Error(`Fixture exited: ${code}`)))
    createInterface({ input: backend.stdout }).on('line', line => {
      try { const message = JSON.parse(line); if (message.event === 'ready') resolve(message.port) } catch {}
    })
  })
  const origin = `http://127.0.0.1:${port}`
  window = new BrowserWindow({ show: false, width: 1280, height: 900, webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true } })
  window.webContents.session.webRequest.onBeforeRequest((details, callback) => {
    const remote = /^https?:/.test(details.url) && !details.url.startsWith(origin + '/')
    if (remote) errors.push(`External request: ${details.url}`)
    callback({ cancel: remote })
  })
  window.webContents.on('console-message', (details) => {
    if (details.level === 'error' && !(details.message.startsWith('Preview playback failed ') && details.message.includes('/clip/smoke.mp4?') && details.message.includes('\"code\":4'))) errors.push(details.message)
  })
  const evaluate = async source => { try { return await window.webContents.executeJavaScript(source) } catch (error) { throw new Error(source + '\n' + error.message + '\n' + errors.join('\n')) } }
  const wait = async source => {
    for (let attempt = 0; attempt < 100; attempt++) {
      if (await evaluate(source)) return
      await new Promise(resolve => setTimeout(resolve, 50))
    }
    throw new Error(`UI condition not met: ${source}`)
  }
  const click = selector => evaluate(`document.querySelector(${JSON.stringify(selector)}).click()`)
  await window.loadURL(origin)
  await wait(`!!document.querySelector('[data-id="smoke"]')`)
  await click('[data-id="smoke"]')
  await wait(`document.querySelector('[data-editor-target="titleInput"]').value === 'Smoke clip'`)
  await evaluate(`(() => { const input = document.querySelector('[data-editor-target="titleInput"]'); input.value = 'Edited smoke'; input.dispatchEvent(new Event('blur')); })()`)
  await wait(`fetch('/api/clip/smoke').then(r => r.json()).then(c => c.title === 'Edited smoke')`)
  await evaluate(`(() => { const input = document.querySelector('[data-clip-list-target="searchInput"]'); input.value = 'Edited'; input.dispatchEvent(new Event('input', {bubbles:true})); document.querySelector('[data-view="groups"]').click(); })()`)
  await wait(`location.pathname === '/groups'`)
  await click('[data-view="all"]')
  await wait(`new URLSearchParams(location.search).get('q') === 'Edited' && location.pathname.includes('smoke')`)
  await click('[aria-label="Settings"]')
  await wait(`document.querySelector('[data-settings-target="overlay"]').style.display === 'flex'`)
  await click('[aria-label="Close settings"]')
  await click('[data-view="groups"]')
  await wait(`!!document.querySelector('.compilation-card summary')`)
  await click('.compilation-card summary')
  await evaluate(`Array.from(document.querySelectorAll('button')).find(b => b.textContent === 'Edit details…').click()`)
  await wait(`!!document.querySelector('dialog[open]')`)
  assert(await evaluate(`(() => { const r = document.querySelector('dialog').getBoundingClientRect(); return r.x > 0 && r.y > 0 && r.right <= innerWidth && r.bottom <= innerHeight; })()`), 'Dialog must fit and be centered')
  await evaluate(`(() => {
    const bytes = Uint8Array.from(atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aC1sAAAAASUVORK5CYII='), c => c.charCodeAt(0));
    const transfer = new DataTransfer(); transfer.items.add(new File([bytes], 'cover.png', {type:'image/png'}));
    const input = document.querySelector('input[name="cover"]'); input.files = transfer.files; input.dispatchEvent(new Event('change'));
  })()`)
  await wait(`document.querySelector('.compilation-cover-preview img').naturalWidth === 1`)
  await click('dialog button[type="submit"]')
  await wait(`!document.querySelector('dialog[open]')`)
  const theme = await evaluate('document.documentElement.dataset.theme')
  await click('[data-controller="theme"]')
  await wait(`document.documentElement.dataset.theme !== ${JSON.stringify(theme)}`)
  assert.equal(errors.length, 0, errors.join('\n'))
  console.log('Browser smoke passed: Stimulus, clip editing, immediate tab-switch search/selection, settings, dialog layout, blob cover preview/save, theme, offline assets. No media processed.')
}
run().then(() => finish(0)).catch(error => { console.error(error); finish(1) })
