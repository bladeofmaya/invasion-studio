const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('invasionStudioImport', Object.freeze({
  chooseRecordings: () => ipcRenderer.invoke('recordings:choose')
}))
