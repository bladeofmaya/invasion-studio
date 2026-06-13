import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["grid", "newGroupCard", "newGroupForm", "newGroupInput"]

  connect() {
    this.groups = []
    this.groupStats = []
    this.element.addEventListener('groups:refresh', () => this.render())
    this.element.addEventListener('nav:changed', (e) => {
      if (e.detail.view === 'groups') {
        this.fetchAndRender()
      }
    })
    this.fetchAndRender()
  }

  async fetchAndRender() {
    await this.fetchGroups()
    await this.fetchGroupStats()
    this.render()
  }

  async fetchGroups() {
    const res = await fetch('/api/groups')
    this.groups = await res.json()
  }

  async fetchGroupStats() {
    const res = await fetch('/api/groups/stats')
    this.groupStats = await res.json()
  }

  render() {
    const grid = this.gridTarget
    const newGroupCard = this.newGroupCardTarget
    const newGroupForm = this.newGroupFormTarget

    // Remove all group cards but keep the new group elements
    const cards = grid.querySelectorAll('.group-card:not(.new-group-card)')
    cards.forEach(c => c.remove())

    if (this.groupStats.length === 0) {
      const empty = document.createElement('div')
      empty.className = 'empty-state'
      empty.textContent = 'No groups yet. Create one!'
      grid.appendChild(empty)
      return
    }

    this.groupStats.forEach(stat => {
      const card = document.createElement('div')
      card.className = 'group-card'
      card.dataset.group = stat.name
      card.addEventListener('click', (e) => {
        if (e.target.tagName === 'BUTTON' || e.target.tagName === 'INPUT') return
        this.openGroup(stat.name)
      })

      const duration = this.formatDuration(stat.total_duration)
      card.innerHTML =
        '<div class="name">' + this.escapeHtml(stat.name) + '</div>' +
        '<div class="stats">' +
        '<span>' + stat.clip_count + '</span> clips &middot; <span>' + duration + '</span> total' +
        '</div>' +
        '<div class="actions">' +
        '<button class="secondary" data-action="click->group-manager#startRename">Rename</button>' +
        '<button class="danger" data-action="click->group-manager#deleteGroup">Delete</button>' +
        '</div>'
      grid.appendChild(card)
    })
  }

  openGroup(name) {
    const navEl = document.querySelector('[data-controller="navigation"]')
    if (navEl) {
      navEl.dataset.navigationSelectedGroupValue = name
    }
  }

  showNewGroupForm() {
    this.newGroupCardTarget.style.display = 'none'
    this.newGroupFormTarget.style.display = 'block'
    this.newGroupInputTarget.focus()
  }

  cancelNewGroupForm() {
    this.newGroupCardTarget.style.display = 'flex'
    this.newGroupFormTarget.style.display = 'none'
    this.newGroupInputTarget.value = ''
  }

  async createGroup() {
    const name = this.newGroupInputTarget.value.trim()
    if (!name) return

    const res = await fetch('/api/groups', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: name })
    })
    if (res.ok) {
      this.newGroupInputTarget.value = ''
      this.cancelNewGroupForm()
      await this.fetchGroups()
      await this.fetchGroupStats()
      this.render()
      this.dispatchGroupsRefresh()
    } else {
      const data = await res.json()
      alert(data.error || 'Failed to create group')
    }
  }

  handleNewGroupKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      this.createGroup()
    }
  }

  async deleteGroup(event) {
    const card = event.currentTarget.closest('.group-card')
    const name = card.dataset.group
    if (!name) return
    if (!confirm('Delete group "' + name + '"? Clips will not be deleted.')) return

    await fetch('/api/groups/' + encodeURIComponent(name), { method: 'DELETE' })
    await this.fetchGroups()
    await this.fetchGroupStats()

    const navEl = document.querySelector('[data-controller="navigation"]')
    const navView = navEl ? navEl.dataset.navigationCurrentViewValue : 'all'
    const navGroup = navEl ? navEl.dataset.navigationSelectedGroupValue : ''

    if (navView === 'groups') {
      this.render()
    } else if (navView === 'group-detail' && navGroup === name) {
      if (navEl) {
        navEl.dataset.navigationCurrentViewValue = 'groups'
      }
    }
    this.dispatchGroupsRefresh()
  }

  startRename(event) {
    const card = event.currentTarget.closest('.group-card')
    const nameDiv = card.querySelector('.name')
    const oldName = card.dataset.group

    const wrapper = document.createElement('div')
    wrapper.style.display = 'flex'
    wrapper.style.gap = '8px'
    wrapper.style.alignItems = 'center'

    const input = document.createElement('input')
    input.type = 'text'
    input.value = oldName
    input.className = 'rename-input'
    input.style.flex = '1'
    input.style.marginBottom = '0'

    const saveBtn = document.createElement('button')
    saveBtn.textContent = 'Save'
    saveBtn.className = 'primary'
    saveBtn.style.padding = '4px 12px'
    saveBtn.style.fontSize = '0.82rem'

    const cancelBtn = document.createElement('button')
    cancelBtn.textContent = 'Cancel'
    cancelBtn.className = 'secondary'
    cancelBtn.style.padding = '4px 12px'
    cancelBtn.style.fontSize = '0.82rem'

    wrapper.appendChild(input)
    wrapper.appendChild(saveBtn)
    wrapper.appendChild(cancelBtn)

    nameDiv.innerHTML = ''
    nameDiv.appendChild(wrapper)
    input.focus()
    input.select()

    const saveHandler = async (e) => {
      e.stopPropagation()
      const newName = input.value.trim()
      if (newName && newName !== oldName) {
        await this.doRename(oldName, newName)
      } else {
        this.render()
      }
    }

    const cancelHandler = (e) => {
      e.stopPropagation()
      this.render()
    }

    const keydownHandler = (e) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        saveHandler(e)
      }
      if (e.key === 'Escape') {
        e.preventDefault()
        cancelHandler(e)
      }
    }

    saveBtn.addEventListener('click', saveHandler)
    cancelBtn.addEventListener('click', cancelHandler)
    input.addEventListener('keydown', keydownHandler)
  }

  async doRename(oldName, newName) {
    const res = await fetch('/api/groups/rename', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ old_name: oldName, new_name: newName })
    })
    if (res.ok) {
      const navEl = document.querySelector('[data-controller="navigation"]')
      if (navEl && navEl.dataset.navigationSelectedGroupValue === oldName) {
        navEl.dataset.navigationSelectedGroupValue = newName
      }
      await this.fetchGroups()
      await this.fetchGroupStats()

      const navView = navEl ? navEl.dataset.navigationCurrentViewValue : 'all'
      if (navView === 'groups') {
        this.render()
      } else if (navView === 'group-detail') {
        // Trigger clip list refresh
        const clipListEl = document.querySelector('[data-controller="clip-list"]')
        if (clipListEl) {
          clipListEl.dispatchEvent(new CustomEvent('clip-list:refresh', { bubbles: true }))
        }
      }
      this.dispatchGroupsRefresh()
    } else {
      const data = await res.json()
      alert(data.error || 'Failed to rename group')
      this.render()
    }
  }

  dispatchGroupsRefresh() {
    this.element.dispatchEvent(new CustomEvent('groups:refresh', { bubbles: true }))
  }
}
