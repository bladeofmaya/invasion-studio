export class WindowHandoff {
  constructor(launcherWindow) {
    this.launcherWindow = launcherWindow
  }

  begin() {
    this.launcherWindow.hide()
  }

  complete(applicationWindow) {
    if (!applicationWindow) throw new Error("application window is required to complete launcher handoff")
    this.launcherWindow.destroy()
  }
}
