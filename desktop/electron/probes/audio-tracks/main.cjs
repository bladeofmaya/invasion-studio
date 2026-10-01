const { app, BrowserWindow, session } = require('electron')
const path = require('node:path')
const { mkdtempSync, rmSync } = require('node:fs')
const os = require('node:os')

// Isolated from the production app and project: no Ruby server or FFmpeg.
const profile = mkdtempSync(path.join(os.tmpdir(), 'invasion-audio-tracks-'))
app.setPath('userData', profile)
async function checkCapabilities() {
  const results = []
  for (const enabled of [false, true]) {
    const window = new BrowserWindow({ show: false, webPreferences: {
      sandbox: true, contextIsolation: true, nodeIntegration: false,
      ...(enabled ? { enableBlinkFeatures: 'AudioVideoTracks' } : {})
    } })
    await window.loadFile(path.join(__dirname, 'index.html'))
    const rendered = await window.webContents.executeJavaScript(`document.querySelector('#diagnostics').value.includes('capability')`)
    if (!rendered) throw new Error('Probe interface did not initialize')
    results.push({ featureEnabled: enabled, ...await window.webContents.executeJavaScript(`(() => {
      const video = document.createElement('video');
      return { exposed: 'audioTracks' in video, count: video.audioTracks?.length,
        listType: video.audioTracks?.constructor.name,
        enabledSetter: typeof globalThis.AudioTrack === 'function' && !!Object.getOwnPropertyDescriptor(AudioTrack.prototype, 'enabled')?.set };
    })()`) })
    window.destroy()
  }
  console.log(JSON.stringify({ electron: process.versions.electron, chrome: process.versions.chrome, results }, null, 2))
  app.quit()
}

app.whenReady().then(async () => {
  if (process.argv.includes('--capabilities')) return checkCapabilities()
  session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) => callback(false))
  const window = new BrowserWindow({
    title: 'Invasion Studio — Direct audio-track probe', width: 1100, height: 850,
    webPreferences: {
      sandbox: true, contextIsolation: true, nodeIntegration: false,
      webSecurity: true, enableBlinkFeatures: 'AudioVideoTracks'
    }
  })
  window.setMenu(null)
  window.webContents.on('will-navigate', event => event.preventDefault())
  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }))
  window.webContents.on('console-message', details => console.log(details.message))
  window.webContents.on('before-input-event', (event, input) => {
    if (input.type === 'keyDown' && input.key === 'F12') {
      event.preventDefault()
      window.webContents.toggleDevTools()
    }
  })
  console.log(JSON.stringify({ electron: process.versions.electron, chrome: process.versions.chrome, feature: 'AudioVideoTracks' }))
  await window.loadFile(path.join(__dirname, 'index.html'))
}).catch(error => { console.error(error); app.exit(1) })
app.on('window-all-closed', () => {
  if (!process.argv.includes('--capabilities')) app.quit()
})
app.on('quit', () => rmSync(profile, { recursive: true, force: true }))
