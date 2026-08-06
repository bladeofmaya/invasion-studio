import { existsSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

import { app, BrowserWindow, dialog, ipcMain, session, shell } from "electron"

import { selectProject, validateProjectPath } from "./project-selection.js"
import { RecentProjects } from "./recent-projects.js"
import { isAllowedAppUrl, isAllowedExternalUrl } from "./security.js"
import { Sidecar } from "./sidecar.js"
import { WindowHandoff } from "./window-handoff.js"

const sourceDirectory = path.dirname(fileURLToPath(import.meta.url))
const electronDirectory = path.dirname(sourceDirectory)
const repositoryRoot = path.resolve(electronDirectory, "..", "..")

let mainWindow = null
let launcherWindow = null
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

function createLauncherWindow() {
  const window = new BrowserWindow({
    title: "Invasion Studio",
    width: 720,
    height: 560,
    minWidth: 600,
    minHeight: 480,
    show: false,
    backgroundColor: "#111315",
    webPreferences: {
      preload: path.join(sourceDirectory, "preload.cjs"),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      webviewTag: false,
      navigateOnDragDrop: false
    }
  })
  window.webContents.on("will-navigate", event => event.preventDefault())
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }))
  window.once("ready-to-show", () => window.show())
  return window
}

function waitForProjectSelection(recentProjects) {
  return new Promise((resolve, reject) => {
    let settled = false

    const assertLauncherSender = event => {
      if (!launcherWindow || event.sender !== launcherWindow.webContents) {
        throw new Error("project selection is only available from the launcher")
      }
    }
    const finish = projectPath => {
      if (settled) return
      settled = true
      cleanup()
      resolve(projectPath)
    }
    const selectPath = async (event, candidate) => {
      assertLauncherSender(event)
      const projectPath = await validateProjectPath(candidate)
      if (!projectPath) throw new Error("The selected project folder is no longer available.")
      setImmediate(() => finish(projectPath))
      return projectPath
    }
    const choose = mode => async event => {
      assertLauncherSender(event)
      const candidate = await selectProject(dialog, mode)
      if (!candidate) return null
      return selectPath(event, candidate)
    }
    const cleanup = () => {
      for (const channel of ["projects:list", "projects:open", "projects:create", "projects:open-recent"]) {
        ipcMain.removeHandler(channel)
      }
    }

    ipcMain.handle("projects:list", event => {
      assertLauncherSender(event)
      return recentProjects.list()
    })
    ipcMain.handle("projects:open", choose("open"))
    ipcMain.handle("projects:create", choose("create"))
    ipcMain.handle("projects:open-recent", selectPath)

    launcherWindow = createLauncherWindow()
    launcherWindow.once("closed", () => {
      launcherWindow = null
      finish(null)
    })
    launcherWindow.loadFile(path.join(sourceDirectory, "launcher.html")).catch(error => {
      cleanup()
      reject(error)
    })
  })
}

async function startupProject(recentProjects) {
  const override = process.env.INVASION_STUDIO_PROJECT
  if (!override) return waitForProjectSelection(recentProjects)

  const projectPath = await validateProjectPath(override)
  if (!projectPath) throw new Error(`INVASION_STUDIO_PROJECT is not a directory: ${override}`)
  return projectPath
}

async function boot() {
  session.defaultSession.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false))
  const recentProjects = new RecentProjects({
    filePath: path.join(app.getPath("userData"), "recent-projects.json")
  })
  const projectPath = await startupProject(recentProjects)
  if (!projectPath) {
    app.quit()
    return
  }

  const windowHandoff = launcherWindow ? new WindowHandoff(launcherWindow) : null
  windowHandoff?.begin()

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

  mainWindow = secureWindow(ready.port)
  await mainWindow.loadURL(`${ready.origin}/`)
  windowHandoff?.complete(mainWindow)
  await recentProjects.add(projectPath).catch(error => console.warn("Could not save recent project:", error))
}

if (!app.requestSingleInstanceLock()) {
  app.quit()
} else {
  app.on("second-instance", () => {
    const window = mainWindow || launcherWindow
    if (!window) return
    if (window.isMinimized()) window.restore()
    window.focus()
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
