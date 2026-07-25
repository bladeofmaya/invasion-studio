import ApplicationController from "./application_controller.js"
import { DEFAULT_FILTER } from "./router_controller.js"

// Render-only controller: reacts to view/group values that the router
// controller (the single source of truth) applies. User actions here
// dispatch router:navigate instead of mutating state directly.
export default class extends ApplicationController {
  static targets = ["tab", "backBtn", "groupGrid", "previewPanel"]
  static values = {
    currentView: { type: String, default: "all" },
    selectedGroup: { type: String, default: "" }
  }

  connect() {
    this.onEditorRefresh = (e) => {
      if (e.detail.reason === 'deleted') {
        // Clear the selection (replace: the deleted clip's URL is stale)
        this.navigateTo({ clipId: '' }, { replace: true })
      }
      const clipListEl = document.querySelector('[data-controller~="clip-list"]')
      if (clipListEl) {
        clipListEl.dispatchEvent(new CustomEvent('clip-list:refresh', { bubbles: true }))
      }
    }
    this.element.addEventListener('editor:refresh', this.onEditorRefresh)
  }

  disconnect() {
    this.element.removeEventListener('editor:refresh', this.onEditorRefresh)
  }

  currentViewValueChanged() {
    this.updateTabs()
    this.updateVisibility()
    this.dispatchStateChanged()
  }

  switchView(event) {
    const view = event.currentTarget.dataset.view
    this.navigateTo({ view: view, group: '', filter: DEFAULT_FILTER, sort: '', clipId: '' })
  }

  goBack() {
    if (this.currentViewValue === 'group-detail') {
      this.navigateTo({ view: 'groups', group: '', clipId: '' })
    }
  }

  openGroup(event) {
    const groupName = event.currentTarget.dataset.group
    if (groupName) {
      this.navigateTo({ view: 'group-detail', group: groupName, clipId: '' })
    }
  }

  updateTabs() {
    this.tabTargets.forEach((tab) => {
      const tabView = tab.dataset.view
      const isActive = (this.currentViewValue === 'all' && tabView === 'all') ||
        (this.currentViewValue === 'groups' && tabView === 'groups') ||
        (this.currentViewValue === 'group-detail' && tabView === 'groups')
      if (isActive) {
        tab.setAttribute('data-active', 'true')
      } else {
        tab.removeAttribute('data-active')
      }
    })
  }

  updateVisibility() {
    if (this.currentViewValue === 'groups') {
      this.backBtnTarget.style.display = 'none'
      this.groupGridTarget.style.display = 'grid'
      this.previewPanelTarget.style.display = 'none'
    } else if (this.currentViewValue === 'group-detail') {
      this.backBtnTarget.style.display = 'inline-block'
      this.groupGridTarget.style.display = 'none'
      this.previewPanelTarget.style.display = 'flex'
    } else {
      this.backBtnTarget.style.display = 'none'
      this.groupGridTarget.style.display = 'none'
      this.previewPanelTarget.style.display = 'flex'
    }
  }

  dispatchStateChanged() {
    this.element.dispatchEvent(new CustomEvent('nav:changed', {
      bubbles: true,
      detail: { view: this.currentViewValue, group: this.selectedGroupValue }
    }))
  }
}
