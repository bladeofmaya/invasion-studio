import ApplicationController from "./application_controller.js"
import { renderIcons } from "../../frontend/icons.js"

const STORAGE_KEY = 'invasion-studio-theme'

export default class extends ApplicationController {
  connect() {
    this.theme = this.savedTheme() || this.systemTheme()
    this.applyTheme()
  }

  toggle() {
    this.theme = this.theme === 'dark' ? 'light' : 'dark'
    localStorage.setItem(STORAGE_KEY, this.theme)
    this.applyTheme()
  }

  savedTheme() {
    const theme = localStorage.getItem(STORAGE_KEY)
    return ['dark', 'light'].includes(theme) ? theme : null
  }

  systemTheme() {
    return window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
  }

  applyTheme() {
    document.documentElement.dataset.theme = this.theme
    const nextTheme = this.theme === 'dark' ? 'light' : 'dark'
    this.element.innerHTML = '<i data-lucide="' + (nextTheme === 'light' ? 'sun' : 'moon') + '" class="size-4"></i>'
    this.element.setAttribute('aria-label', 'Switch to ' + nextTheme + ' mode')
    this.element.setAttribute('title', 'Switch to ' + nextTheme + ' mode')
    renderIcons(this.element)
  }
}
