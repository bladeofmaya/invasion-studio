import { existsSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import { app, BrowserWindow, dialog, session, shell } from "electron"

import { isAllowedAppUrl, isAllowedExternalUrl } from "./security.js"
import { Sidecar } from "./sidecar.js"

const sourceDirectory = path.dirname(fileURLToPath(import.meta.url))
const electronDirectory = path.dirname(sourceDirectory)
const repositoryRoot = path.resolve(electronDirectory, "..", "..")

let mainWindow = null
let quitting = false
const sidecar = new Sidecar()

function packagedResource(...segments) {
  return path.join(process.resourcesPath, ...segments)
}

function sidecarExecutable() {
  if (process.env.INVASION_STUDIO_SIDECAR) return process.env.INVASION_STUDIO_SIDECAR
  if (app.isPackaged) return packagedResource("invasion-studio")
  return path.join(repositoryRoot, "pkg", "sidecar", "linux-x64", "invasion-studio")
}

function sidecarEnvironment() {
  const environment = { ...process.env }
  if (!app.isPackaged) return environment

  const tools = {
    INVASION_STUDIO_FFMPEG: packagedResource("tools", "ffmpeg"),
    INVASION_STUDIO_FFPROBE: packagedResource("tools", "ffprobe"),
    INVASION_STUDIO_TESSERACT: packagedResource("tools", "tesseract")
  }

  for (const [name, executable] of Object.entries(tools)) {
    if (existsSync(executable)) environment[name] = executable
  }

  const tessdata = packagedResource("tessdata")
  if (existsSync(tessdata)) environment.TESSDATA_PREFIX = tessdata
  return environment
}

function secureWindow(port) {
  const window = new BrowserWindow({
    title: "Invasion Studio",
    width: 1280,
    height: 800,
    minWidth: 960,
    minHeight: 640,
    show: false,
    backgroundColor: "#111111",
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      webviewTag: false,
      navigateOnDragDrop: false
    }
  })

  window.webContents.on("will-navigate", (event, url) => {
    if (!isAllowedAppUrl(url, port)) event.preventDefault()
  })
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (isAllowedExternalUrl(url)) void shell.openExternal(url)
    return { action: "deny" }
  })
  window.once("ready-to-show", () => window.show())
  return window
}

async function boot() {
  const projectPath = process.env.INVASION_STUDIO_PROJECT
  if (!projectPath) throw new Error("INVASION_STUDIO_PROJECT is required")

  const executable = sidecarExecutable()
  if (!existsSync(executable)) {
    throw new Error(`packaged sidecar was not found at ${executable}`)
  }

  const ready = await sidecar.start({
    executable,
    projectPath,
    parentPid: process.pid,
    env: sidecarEnvironment()
  })

  session.defaultSession.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false))
  mainWindow = secureWindow(ready.port)
  await mainWindow.loadURL(`${ready.origin}/`)
}

if (!app.requestSingleInstanceLock()) {
  app.quit()
} else {
  app.on("second-instance", () => {
    if (!mainWindow) return
    if (mainWindow.isMinimized()) mainWindow.restore()
    mainWindow.focus()
  })

  app.whenReady().then(boot).catch(async error => {
    await sidecar.stop()
    dialog.showErrorBox("Invasion Studio could not start", error.message)
    app.exit(1)
  })

  app.on("window-all-closed", () => app.quit())
  app.on("before-quit", event => {
    if (quitting) return
    event.preventDefault()
    quitting = true
    sidecar.stop().finally(() => app.quit())
  })
}
