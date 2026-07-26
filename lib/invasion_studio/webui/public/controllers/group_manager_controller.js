import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["grid", "newGroupCard", "newGroupForm", "newGroupInput"]

  connect() {
    this.groups = []
    this.groupStats = []
    this.onGroupsRefresh = () => this.fetchAndRender()
    this.onNavChanged = (e) => {
      if (e.detail.view === 'groups') {
        this.fetchAndRender()
      }
    }
    this.element.addEventListener('groups:refresh', this.onGroupsRefresh)
    this.element.addEventListener('nav:changed', this.onNavChanged)
    this.fetchAndRender()
  }

  disconnect() {
    this.element.removeEventListener('groups:refresh', this.onGroupsRefresh)
    this.element.removeEventListener('nav:changed', this.onNavChanged)
  }

  async fetchAndRender() {
    await this.fetchGroups()
    await this.fetchGroupStats()
    this.render()
  }

  async fetchGroups() {
    this.groups = await this.fetchJson('/api/groups')
  }

  async fetchGroupStats() {
    this.groupStats = await this.fetchJson('/api/groups/stats')
  }

  render() {
    const grid = this.gridTarget

    // Remove all rendered group cards (and empty-state message) but keep the
    // static new-group elements
    const cards = grid.querySelectorAll('.group-card, .group-grid-empty')
    cards.forEach(c => c.remove())

    if (this.groupStats.length === 0) {
      const empty = document.createElement('div')
      empty.className = 'group-grid-empty text-center py-10 text-text-muted text-sm'
      empty.textContent = 'No groups yet. Create one!'
      grid.appendChild(empty)
      return
    }

    this.groupStats.forEach(stat => {
      const card = document.createElement('div')
      card.className = 'group-card bg-surface border border-border rounded-lg p-5 cursor-pointer hover:border-accent hover:-translate-y-0.5'
      card.dataset.group = stat.name
      card.addEventListener('click', (e) => {
        if (e.target.tagName === 'BUTTON' || e.target.tagName === 'INPUT') return
        this.openGroup(stat.name)
      })

      const duration = this.formatDuration(stat.total_duration)
      card.innerHTML =
        '<div class="text-lg font-semibold text-text-primary mb-2">' + this.escapeHtml(stat.name) + '</div>' +
        '<div class="text-sm text-text-muted mb-3">' +
        '<span class="text-text-secondary font-medium">' + stat.clip_count + '</span> clips &middot; <span class="text-text-secondary font-medium">' + duration + '</span> total' +
        '</div>' +
        '<div class="flex gap-2">' +
        '<button class="bg-transparent border border-text-muted text-text-muted px-3 py-1 text-xs rounded cursor-pointer hover:border-text-primary hover:text-text-primary" data-action="click->group-manager#startRename">Rename</button>' +
        '<button class="bg-danger text-danger-fg border-none px-3 py-1 text-xs rounded cursor-pointer hover:bg-danger-hover" data-action="click->group-manager#deleteGroup">Delete</button>' +
        '</div>'
      grid.appendChild(card)
    })
  }

  openGroup(name) {
    this.navigateTo({ view: 'group-detail', group: name, clipId: '' })
  }

  showNewGroupForm() {
    this.newGroupCardTarget.hidden = true
    this.newGroupFormTarget.hidden = false
    this.newGroupInputTarget.focus()
  }

  cancelNewGroupForm() {
    this.newGroupCardTarget.hidden = false
    this.newGroupFormTarget.hidden = true
    this.newGroupInputTarget.value = ''
  }

  async createGroup(event) {
    event.preventDefault()
    const name = this.newGroupInputTarget.value.trim()
    if (!name) return

    const btn = this.newGroupFormTarget.querySelector('button[type="submit"]')
    if (btn) {
      btn.textContent = 'Creating...'
      btn.disabled = true
      btn.classList.add('opacity-50')
    }

    try {
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
        this.showSuccess('Group created')
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to create group')
      }
    } catch (err) {
      this.showError('Failed to create group')
    } finally {
      if (btn) {
        btn.textContent = 'Create group'
        btn.disabled = false
        btn.classList.remove('opacity-50')
      }
    }
  }

  async deleteGroup(event) {
    const card = event.currentTarget.closest('.group-card')
    const name = card.dataset.group
    if (!name) return
    if (!confirm('Delete group "' + name + '"? Clips will not be deleted.')) return

    const btn = event.currentTarget
    btn.textContent = 'Deleting...'
    btn.disabled = true
    btn.classList.add('opacity-50')

    try {
      await fetch('/api/groups/' + encodeURIComponent(name), { method: 'DELETE' })
      await this.fetchGroups()
      await this.fetchGroupStats()

      const nav = this.getNavState()
      if (nav.view === 'groups') {
        this.render()
      } else if (nav.view === 'group-detail' && nav.group === name) {
        this.navigateTo({ view: 'groups', group: '', clipId: '' })
      }
      this.dispatchGroupsRefresh()
      this.showSuccess('Group deleted')
    } catch (err) {
      this.showError('Failed to delete group')
    } finally {
      btn.textContent = 'Delete'
      btn.disabled = false
      btn.classList.remove('opacity-50')
    }
  }

  startRename(event) {
    const card = event.currentTarget.closest('.bg-surface')
    const nameDiv = card.querySelector('.text-lg')
    const oldName = card.dataset.group

    const wrapper = document.createElement('div')
    wrapper.className = 'flex gap-2 items-center'

    const input = document.createElement('input')
    input.type = 'text'
    input.value = oldName
    input.className = 'bg-surface-overlay text-text-primary border border-accent rounded p-2.5 text-base w-full mb-0 outline-none flex-1'

    const saveBtn = document.createElement('button')
    saveBtn.textContent = 'Save'
    saveBtn.className = 'bg-primary text-primary-fg border-none px-4 py-1 text-sm rounded cursor-pointer hover:bg-primary-hover'

    const cancelBtn = document.createElement('button')
    cancelBtn.textContent = 'Cancel'
    cancelBtn.className = 'bg-transparent border border-text-muted text-text-muted px-4 py-1 text-sm rounded cursor-pointer hover:border-text-primary hover:text-text-primary'

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
    try {
      const res = await fetch('/api/groups/rename', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ old_name: oldName, new_name: newName })
      })
      if (res.ok) {
        const nav = this.getNavState()
        if (nav.view === 'group-detail' && nav.group === oldName) {
          // Same logical location under a new name — replace, not push. The
          // router applies the new group value, which refreshes the clip list.
          this.navigateTo({ view: 'group-detail', group: newName }, { replace: true })
        }
        await this.fetchGroups()
        await this.fetchGroupStats()
        if (nav.view === 'groups') {
          this.render()
        }
        this.dispatchGroupsRefresh()
        this.showSuccess('Group renamed')
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to rename group')
        this.render()
      }
    } catch (err) {
      this.showError('Failed to rename group')
      this.render()
    }
  }

  dispatchGroupsRefresh() {
    this.element.dispatchEvent(new CustomEvent('groups:refresh', { bubbles: true }))
  }
}
