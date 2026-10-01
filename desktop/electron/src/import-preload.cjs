const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('invasionStudioImport', Object.freeze({
  chooseRecordings: () => ipcRenderer.invoke('recordings:choose')
}))

contextBridge.exposeInMainWorld('invasionStudioStorage', Object.freeze({
  openProjectFolder: () => ipcRenderer.invoke('project:open-folder')
}))
