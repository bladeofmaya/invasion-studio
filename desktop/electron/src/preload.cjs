const { contextBridge, ipcRenderer } = require("electron")

contextBridge.exposeInMainWorld("invasionStudio", Object.freeze({
  listProjects: () => ipcRenderer.invoke("projects:list"),
  openProject: () => ipcRenderer.invoke("projects:open"),
  createProject: () => ipcRenderer.invoke("projects:create"),
  openRecentProject: projectPath => ipcRenderer.invoke("projects:open-recent", projectPath)
}))
