import { isAllowedAppUrl } from './security.js'

export async function selectRecordings(event, window, port, dialog) {
  if (!window || event.sender !== window.webContents ||
      event.senderFrame !== window.webContents.mainFrame ||
      !isAllowedAppUrl(event.senderFrame.url, port)) {
    throw new Error('Recording selection is only available from the application window')
  }
  const result = await dialog.showOpenDialog(window, {
    title: 'Select recordings in playback order',
    buttonLabel: 'Use recordings',
    properties: ['openFile', 'multiSelections'],
    filters: [{ name: 'Videos', extensions: ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'wmv', 'm4v', 'mpeg', 'mpg'] }]
  })
  return result.canceled ? null : result.filePaths.sort()
}
