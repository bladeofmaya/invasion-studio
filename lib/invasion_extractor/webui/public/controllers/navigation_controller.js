import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["tab", "backBtn", "groupGrid", "previewPanel", "newGroupCard", "newGroupForm", "clipListPanel", "exportArea"]
  static values = {
    currentView: { type: String, default: "all" },
    selectedGroup: { type: String, default: "" }
  }

  connect() {
    this.currentViewValue = 'all'
    this.element.addEventListener('editor:refresh', (e) => {
      if (e.detail.reason === 'deleted') {
        this.resetEditor()
        const clipListEl = document.querySelector('[data-controller="clip-list"]')
        if (clipListEl) {
          clipListEl.dataset.clipListSelectedClipIdValue = ''
        }
      }
      const clipListEl = document.querySelector('[data-controller="clip-list"]')
      if (clipListEl) {
        clipListEl.dispatchEvent(new CustomEvent('clip-list:refresh', { bubbles: true }))
      }
    })
  }

  currentViewValueChanged() {
    this.updateTabs()
    this.updateVisibility()
    this.dispatchStateChanged()

    if (this.currentViewValue === 'all') {
      this.syncClipList({ view: 'all', group: '', filter: 'everything', selectedClipId: '' })
      this.resetEditor()
    } else if (this.currentViewValue === 'groups') {
      this.syncClipList({ view: 'groups', selectedClipId: '' })
      this.resetEditor()
      this.dispatch('render-groups', { bubbles: true })
    } else if (this.currentViewValue === 'group-detail') {
      this.syncClipList({ view: 'group-detail', group: this.selectedGroupValue, selectedClipId: '' })
      this.resetEditor()
    }
  }

  selectedGroupValueChanged() {
    if (this.selectedGroupValue) {
      this.currentViewValue = 'group-detail'
    }
  }

  switchView(event) {
    const view = event.currentTarget.dataset.view
    this.selectedGroupValue = ''
    this.currentViewValue = view
  }

  goBack() {
    if (this.currentViewValue === 'group-detail') {
      this.selectedGroupValue = ''
      this.currentViewValue = 'groups'
    }
  }

  openGroup(event) {
    const groupName = event.currentTarget.dataset.group
    if (groupName) {
      this.selectedGroupValue = groupName
    }
  }

  updateTabs() {
    this.tabTargets.forEach((tab) => {
      const tabView = tab.dataset.view
      const isActive = (this.currentViewValue === 'all' && tabView === 'all') ||
        (this.currentViewValue === 'groups' && tabView === 'groups') ||
        (this.currentViewValue === 'group-detail' && tabView === 'groups')
      tab.classList.toggle('active', isActive)
    })
  }

  updateVisibility() {
    if (this.currentViewValue === 'groups') {
      this.backBtnTarget.style.display = 'none'
      this.groupGridTarget.style.display = 'grid'
      this.newGroupCardTarget.style.display = 'flex'
      this.previewPanelTarget.style.display = 'none'
    } else if (this.currentViewValue === 'group-detail') {
      this.backBtnTarget.style.display = 'inline-block'
      this.groupGridTarget.style.display = 'none'
      this.newGroupCardTarget.style.display = 'none'
      this.previewPanelTarget.style.display = 'flex'
    } else {
      this.backBtnTarget.style.display = 'none'
      this.groupGridTarget.style.display = 'none'
      this.newGroupCardTarget.style.display = 'none'
      this.previewPanelTarget.style.display = 'flex'
    }
  }

  syncClipList(options) {
    const clipListEl = document.querySelector('[data-controller="clip-list"]')
    if (!clipListEl) return
    if (options.view !== undefined) clipListEl.dataset.clipListViewValue = options.view
    if (options.group !== undefined) clipListEl.dataset.clipListGroupValue = options.group
    if (options.filter !== undefined) clipListEl.dataset.clipListFilterValue = options.filter
    if (options.selectedClipId !== undefined) clipListEl.dataset.clipListSelectedClipIdValue = options.selectedClipId
  }

  dispatchStateChanged() {
    this.element.dispatchEvent(new CustomEvent('nav:changed', {
      bubbles: true,
      detail: { view: this.currentViewValue, group: this.selectedGroupValue }
    }))
  }
}
