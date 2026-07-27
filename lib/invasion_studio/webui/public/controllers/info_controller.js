import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["overlay"]

  open() {
    this.overlayTarget.style.display = 'flex'
  }

  close() {
    this.overlayTarget.style.display = 'none'
  }

  backdropClose(event) {
    if (event.target === this.overlayTarget) this.close()
  }
}
