import { isAllowedAppUrl } from './security.js'

export async function openProjectFolder(event, window, port, projectPath, shell) {
  if (!window || event.sender !== window.webContents ||
      event.senderFrame !== window.webContents.mainFrame ||
      !isAllowedAppUrl(event.senderFrame.url, port)) {
    throw new Error('Opening the project folder is only available from the application window')
  }
  const error = await shell.openPath(projectPath)
  if (error) throw new Error(error)
}
