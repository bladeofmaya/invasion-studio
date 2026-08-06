import ApplicationController from "./application_controller.js"
import { renderIcons } from "../../frontend/icons.js"

export default class extends ApplicationController {
  static targets = ["grid", "newGroupCard", "newGroupForm", "newGroupInput"]

  connect() {
    this.groupStats = []
    this.onGroupsRefresh = () => {
      if (this.getNavState().view === 'groups') this.fetchAndRender()
    }
    this.onNavChanged = (e) => {
      if (e.detail.view === 'groups') {
        this.fetchAndRender()
      }
    }
    // document-level: these events originate outside this element's subtree
    // (clip list, navigation), so element-scoped listeners never fire.
    document.addEventListener('groups:refresh', this.onGroupsRefresh)
    document.addEventListener('nav:changed', this.onNavChanged)
    if (this.getNavState().view === 'groups') this.fetchAndRender()
  }

  disconnect() {
    document.removeEventListener('groups:refresh', this.onGroupsRefresh)
    document.removeEventListener('nav:changed', this.onNavChanged)
  }

  async fetchAndRender() {
    await this.fetchGroupStats()
    this.render()
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
      empty.textContent = 'No compilations yet. Create one!'
      grid.appendChild(empty)
      return
    }

    this.groupStats.forEach(stat => {
      const card = document.createElement('div')
      card.className = 'group-card bg-surface border border-border rounded-lg p-4 cursor-pointer hover:border-accent hover:-translate-y-0.5'
      card.dataset.group = stat.name
      card.addEventListener('click', (e) => {
        if (e.target.closest('button, input')) return
        this.openGroup(stat.name)
      })

      const duration = this.formatDuration(stat.total_duration)
      card.innerHTML =
        '<div class="flex items-start justify-between gap-2 mb-1.5">' +
        '<div class="group-name text-base font-semibold text-text-primary min-w-0 flex-1 whitespace-nowrap overflow-hidden text-ellipsis">' + this.escapeHtml(stat.name) + '</div>' +
        '<div class="group-actions flex gap-1 flex-shrink-0">' +
        '<button class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-text-primary hover:bg-surface-hover" title="Rename" aria-label="Rename" data-action="click->group-manager#startRename"><i data-lucide="pencil" class="size-3.5"></i></button>' +
        '<button class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-danger hover:bg-surface-hover" title="Delete" aria-label="Delete" data-action="click->group-manager#deleteGroup"><i data-lucide="trash-2" class="size-3.5"></i></button>' +
        '</div>' +
        '</div>' +
        '<div class="text-sm text-text-muted">' +
        '<span class="text-text-secondary font-medium">' + stat.clip_count + '</span> clips &middot; <span class="text-text-secondary font-medium">' + duration + '</span> total' +
        '</div>'
      renderIcons(card)
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
        await this.fetchAndRender()
        this.dispatchGroupsRefresh()
        this.showSuccess('Compilation created')
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to create compilation')
      }
    } catch (err) {
      this.showError('Failed to create compilation')
    } finally {
      if (btn) {
        btn.textContent = 'Create compilation'
        btn.disabled = false
        btn.classList.remove('opacity-50')
      }
    }
  }

  async deleteGroup(event) {
    const card = event.currentTarget.closest('.group-card')
    const name = card.dataset.group
    if (!name) return
    if (!confirm('Delete compilation "' + name + '"? Clips will not be deleted.')) return

    const btn = event.currentTarget
    btn.disabled = true
    btn.classList.add('opacity-50')

    try {
      await fetch('/api/groups/' + encodeURIComponent(name), { method: 'DELETE' })
      await this.fetchGroupStats()

      const nav = this.getNavState()
      if (nav.view === 'groups') {
        this.render()
      } else if (nav.view === 'group-detail' && nav.group === name) {
        this.navigateTo({ view: 'groups', group: '', clipId: '' })
      }
      this.dispatchGroupsRefresh()
      this.showSuccess('Compilation deleted')
    } catch (err) {
      this.showError('Failed to delete compilation')
    } finally {
      btn.disabled = false
      btn.classList.remove('opacity-50')
    }
  }

  startRename(event) {
    const card = event.currentTarget.closest('.group-card')
    const nameDiv = card.querySelector('.group-name')
    const actions = card.querySelector('.group-actions')
    const oldName = card.dataset.group

    // Undo the title truncation so the inline input isn't clipped
    nameDiv.classList.remove('whitespace-nowrap', 'overflow-hidden', 'text-ellipsis')

    const input = document.createElement('input')
    input.type = 'text'
    input.maxLength = 100
    input.value = oldName
    input.className = 'bg-surface-overlay text-text-primary border border-accent rounded px-2 py-1 text-base w-full outline-none'
    nameDiv.innerHTML = ''
    nameDiv.appendChild(input)

    // Swap the pencil/trash icons for check (save) and cross (cancel)
    actions.innerHTML =
      '<button class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-success hover:bg-surface-hover" title="Save" aria-label="Save"><i data-lucide="check" class="size-3.5"></i></button>' +
      '<button class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-danger hover:bg-surface-hover" title="Cancel" aria-label="Cancel"><i data-lucide="x" class="size-3.5"></i></button>'
    const [saveBtn, cancelBtn] = actions.querySelectorAll('button')
    renderIcons(actions)

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
        await this.fetchGroupStats()
        if (nav.view === 'groups') {
          this.render()
        }
        this.dispatchGroupsRefresh()
        this.showSuccess('Compilation renamed')
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to rename compilation')
        this.render()
      }
    } catch (err) {
      this.showError('Failed to rename compilation')
      this.render()
    }
  }

  dispatchGroupsRefresh() {
    document.dispatchEvent(new CustomEvent('groups:refresh'))
  }
}
