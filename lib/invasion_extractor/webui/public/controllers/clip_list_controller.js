import ApplicationController from "./application_controller.js"

export default class extends ApplicationController {
  static targets = ["container", "panelTitle", "filterDropdown", "filterSelect", "groupExport"]
  static values = {
    view: { type: String, default: "all" },
    filter: { type: String, default: "everything" },
    group: { type: String, default: "" },
    selectedClipId: { type: String, default: "" }
  }

  connect() {
    this.groups = []
    this.clips = []
    this.element.addEventListener('clip-list:refresh', () => this.fetchAndRender())
    this.fetchGroups().then(() => this.fetchAndRender())
    this.setupKeyboardShortcuts()
  }

  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Only handle j/k if not in an input/textarea
      const active = document.activeElement
      if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable)) return
      if (e.key === 'j' || e.key === 'J') {
        e.preventDefault()
        this.selectNextClip(1)
      } else if (e.key === 'k' || e.key === 'K') {
        e.preventDefault()
        this.selectNextClip(-1)
      }
    })
  }

  selectNextClip(direction) {
    if (this.clips.length === 0) return
    const currentIndex = this.clips.findIndex(c => c.id === this.selectedClipIdValue)
    let nextIndex = currentIndex + direction
    if (nextIndex < 0) nextIndex = this.clips.length - 1
    if (nextIndex >= this.clips.length) nextIndex = 0
    this.selectClip(this.clips[nextIndex].id)
  }

  viewValueChanged() { this.fetchAndRender() }
  filterValueChanged() {
    this.fetchAndRender()
    if (this.hasFilterSelectTarget) {
      this.filterSelectTarget.value = this.filterValue
    }
  }
  groupValueChanged() { this.fetchAndRender() }

  selectedClipIdValueChanged() {
    this.containerTarget.querySelectorAll('[data-id]').forEach(el => {
      const isSelected = el.dataset.id === this.selectedClipIdValue
      if (isSelected) {
        el.classList.add('bg-surface-hover', 'border-accent')
        el.classList.remove('bg-surface')
      } else {
        el.classList.remove('bg-surface-hover', 'border-accent')
        el.classList.add('bg-surface')
      }
    })
  }

  async fetchGroups() {
    const res = await fetch('/api/groups')
    this.groups = await res.json()
  }

  async fetchAndRender() {
    if (this.viewValue === 'groups') {
      this.containerTarget.innerHTML = ''
      this.updateVisibility()
      return
    }

    const url = this.buildUrl()
    try {
      const res = await fetch(url)
      if (!res.ok) {
        console.error('Failed to load clips:', res.status)
        return
      }
      const allClips = await res.json()
      this.clips = this.applyFilter(allClips)
      this.render()
      this.updateVisibility()
    } catch (e) {
      console.error('Error loading clips:', e)
    }
  }

  buildUrl() {
    if (this.groupValue) {
      return '/api/clips?group=' + encodeURIComponent(this.groupValue)
    }
    return '/api/clips?all=true'
  }

  applyFilter(allClips) {
    if (this.filterValue === 'deleted') {
      return allClips.filter(c => c.deleted)
    } else if (this.filterValue === 'unassigned') {
      const assignedIds = new Set()
      this.groups.forEach(g => g.clip_ids.forEach(id => assignedIds.add(id)))
      return allClips.filter(c => !c.deleted && !assignedIds.has(c.id))
    } else if (this.filterValue === 'assigned') {
      const assignedIds = new Set()
      this.groups.forEach(g => g.clip_ids.forEach(id => assignedIds.add(id)))
      return allClips.filter(c => !c.deleted && assignedIds.has(c.id))
    } else {
      return allClips.filter(c => !c.deleted)
    }
  }

  updateVisibility() {
    if (this.viewValue === 'groups') {
      this.containerTarget.style.display = 'none'
      this.filterDropdownTarget.style.display = 'none'
      this.groupExportTarget.style.display = 'none'
      this.panelTitleTarget.textContent = 'Groups'
    } else if (this.viewValue === 'group-detail') {
      this.containerTarget.style.display = 'block'
      this.filterDropdownTarget.style.display = 'none'
      this.groupExportTarget.style.display = 'flex'
      this.panelTitleTarget.textContent = this.groupValue + ' (' + this.clips.length + ' clips)'
    } else {
      this.containerTarget.style.display = 'block'
      this.filterDropdownTarget.style.display = 'block'
      this.groupExportTarget.style.display = 'none'
      const filterLabel = {
        everything: 'Everything',
        unassigned: 'Unassigned',
        assigned: 'Assigned',
        deleted: 'Deleted'
      }
      this.panelTitleTarget.textContent = filterLabel[this.filterValue] + ' (' + this.clips.length + ')'
    }
  }

  render() {
    const container = this.containerTarget
    container.innerHTML = ''

    if (this.clips.length === 0) {
      const message = this.viewValue === 'all'
        ? 'Extract some clips first.'
        : 'Add clips to this group from "All Clips".'
      container.innerHTML = '<div class="text-center py-10 text-text-muted text-sm">No clips here. ' + message + '</div>'
      return
    }

    this.clips.forEach((clip, index) => {
      const div = document.createElement('div')
      div.className = 'bg-surface border border-border rounded-md p-3.5 mb-2 flex items-center gap-3 cursor-pointer hover:border-border-active' + (clip.id === this.selectedClipIdValue ? ' bg-surface-hover border-accent' : '')
      div.dataset.index = index
      div.dataset.id = clip.id

      const noteText = clip.note ? clip.note : 'No note'
      const noteClass = clip.note ? '' : ' italic opacity-60'
      const rating = clip.rating || 0
        const resultBadge = clip.result ? '<span class="inline-block px-2 py-0.5 rounded text-xs font-semibold uppercase tracking-wider mr-1.5 ' + (clip.result === 'win' ? 'text-success bg-success/15' : clip.result === 'loss' ? 'text-danger bg-danger/15' : 'text-text-muted bg-text-muted/15') + '">' + clip.result + '</span>' : ''
      const displayTitle = clip.title ? clip.title : clip.filename

      let groupActionHtml = ''
      if (this.filterValue === 'deleted') {
        groupActionHtml = '<button class="bg-transparent border border-text-muted text-text-muted px-3 py-1 text-xs rounded cursor-pointer hover:border-text-primary hover:text-text-primary">Restore</button>'
      } else if (this.viewValue === 'all') {
        const assignedGroups = clip.groups || []
        if (assignedGroups.length > 0) {
          const groupName = this.escapeHtml(assignedGroups[0])
          groupActionHtml = '<div class="text-xs text-text-muted whitespace-nowrap cursor-pointer underline">' + groupName + '</div>'
        } else {
          const options = this.groups.map(g => '<option value="' + this.escapeHtml(g.name) + '">' + this.escapeHtml(g.name) + '</option>').join('')
                groupActionHtml = '<select class="bg-surface-secondary text-text-primary border border-border px-2 py-1 rounded text-xs cursor-pointer"><option value="">Add to group...</option>' + options + '<option value="__new__">+ New Group...</option></select>'
        }
      } else {
        groupActionHtml = '<button class="bg-transparent border border-text-muted text-text-muted px-3 py-1 text-xs rounded cursor-pointer hover:border-text-primary hover:text-text-primary">Remove</button>'
      }

      const dragHandle = (this.viewValue === 'group-detail' && this.filterValue !== 'deleted')
        ? '<span class="text-text-muted cursor-grab text-lg px-1 select-none">&#x2630;</span>'
        : ''

      div.innerHTML = dragHandle +
        '<div class="flex-1 min-w-0">' +
        '<div class="font-medium text-sm mb-1 whitespace-nowrap overflow-hidden text-ellipsis">' + this.escapeHtml(displayTitle) + '</div>' +
        '<div class="text-xs text-text-muted whitespace-nowrap overflow-hidden text-ellipsis' + noteClass + '">' + this.escapeHtml(noteText) + '</div>' +
        '</div>' +
        '<div class="flex flex-col gap-1 items-end">' +
        '<div class="inline-flex items-center gap-1">' +
        '<div class="inline-flex gap-0.5 text-base">' + this.renderStarsDisplay(rating) + '</div>' + resultBadge +
        '</div>' +
        groupActionHtml +
        '</div>'

      // Attach event listeners
      div.addEventListener('click', (e) => {
        if (e.target.tagName === 'SELECT' || e.target.tagName === 'BUTTON' || e.target.classList.contains('cursor-grab')) return
        this.selectClip(clip.id)
      })

      const restoreBtn = div.querySelector('button')
      if (restoreBtn && this.filterValue === 'deleted') {
        restoreBtn.addEventListener('click', (e) => {
          e.stopPropagation()
          this.restoreClip(clip.id)
        })
      }

      const removeBtn = div.querySelector('button')
      if (removeBtn && this.viewValue !== 'all' && this.filterValue !== 'deleted') {
        removeBtn.addEventListener('click', (e) => {
          e.stopPropagation()
          this.removeFromGroup(clip.id)
        })
      }

      const select = div.querySelector('select')
      if (select) {
        select.addEventListener('change', (e) => {
          e.stopPropagation()
          this.addToGroup(e.target, clip.id)
        })
      }

      const badge = div.querySelector('.group-badge')
      if (badge) {
        badge.addEventListener('click', (e) => {
          e.stopPropagation()
          const navEl = document.querySelector('[data-controller="navigation"]')
          if (navEl) {
            navEl.dataset.navigationSelectedGroupValue = badge.textContent
          }
        })
      }

      if (this.viewValue === 'group-detail' && this.filterValue !== 'deleted') {
        div.draggable = true
        div.addEventListener('dragstart', (e) => {
          e.dataTransfer.setData('text/plain', index)
          div.classList.add('opacity-40')
        })
        div.addEventListener('dragend', () => {
          div.classList.remove('opacity-40')
        })
        div.addEventListener('dragover', (e) => {
          e.preventDefault()
        })
        div.addEventListener('drop', (e) => {
          e.preventDefault()
          e.stopPropagation()
          const oldIndex = parseInt(e.dataTransfer.getData('text/plain'))
          const newIndex = parseInt(div.dataset.index)
          if (oldIndex !== newIndex && !isNaN(oldIndex) && !isNaN(newIndex)) {
            this.reorderClip(oldIndex, newIndex)
          }
        })
      }

      container.appendChild(div)
    })
  }

  async selectClip(id) {
    this.selectedClipIdValue = id
    const res = await fetch('/api/clip/' + encodeURIComponent(id))
    const clip = await res.json()
    if (clip.error) {
      this.resetEditor()
      return
    }
    document.getElementById('meta-filename').textContent = this.escapeHtml(clip.filename)
    const videoPlayerEl = document.querySelector('[data-controller="video-player"]')
    if (videoPlayerEl) {
      videoPlayerEl.dataset.videoPlayerClipIdValue = clip.id
      videoPlayerEl.dataset.videoPlayerSrcValue = '/clip/' + encodeURIComponent(clip.filename)
      videoPlayerEl.dataset.videoPlayerCutsValue = JSON.stringify(clip.cuts || [])
    }
    const editorEl = document.querySelector('[data-controller="editor"]')
    if (editorEl) {
      editorEl.dataset.editorClipIdValue = clip.id
    }
    // Scroll selected clip into view
    const selectedEl = this.containerTarget.querySelector('[data-id="' + id + '"]')
    if (selectedEl) {
      selectedEl.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
    }
  }

  async exportGroup() {
    const nav = this.getNavState()
    const group = nav.group
    if (!group) {
      alert('No group selected')
      return
    }
    const filename = this.groupExportTarget.querySelector('input').value.trim()
    const btn = this.groupExportTarget.querySelector('button')
    const originalText = btn.textContent
    btn.textContent = 'Exporting...'
    btn.disabled = true
    btn.classList.add('opacity-50')

    try {
      const res = await fetch('/api/export', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ group: group, output_basename: filename || null })
      })
      const data = await res.json()
      if (res.ok) {
        this.showSuccess('Exported successfully!')
      } else {
        this.showError('Export failed: ' + (data.error || 'Unknown error'))
      }
    } catch (err) {
      this.showError('Export failed: network error')
    } finally {
      btn.textContent = originalText
      btn.disabled = false
      btn.classList.remove('opacity-50')
    }
  }

  async reorderClip(oldIndex, newIndex) {
    try {
      const res = await fetch('/api/reorder', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ group: this.groupValue, old_index: oldIndex, new_index: newIndex })
      })
      if (res.ok) {
        this.fetchAndRender()
      } else {
        this.showError('Failed to reorder')
      }
    } catch (err) {
      this.showError('Failed to reorder')
    }
  }

  async restoreClip(id) {
    try {
      const res = await fetch('/api/clip/' + encodeURIComponent(id), { method: 'DELETE' })
      if (res.ok) {
        this.fetchAndRender()
        this.showSuccess('Clip restored')
      } else {
        this.showError('Failed to restore clip')
      }
    } catch (err) {
      this.showError('Failed to restore clip')
    }
  }

  async addToGroup(select, clipId) {
    const groupName = select.value
    select.value = ''
    if (!groupName) return

    if (groupName === '__new__') {
      const name = prompt('Enter group name:')
      if (!name || !name.trim()) return
      try {
        const createRes = await fetch('/api/groups', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: name.trim() })
        })
        if (!createRes.ok) {
          const data = await createRes.json()
          this.showError(data.error || 'Failed to create group')
          return
        }
        await this.fetchGroups()
        this.dispatchGroupsRefresh()
        await this.doAddToGroup(name.trim(), clipId)
      } catch (err) {
        this.showError('Failed to create group')
      }
    } else {
      await this.doAddToGroup(groupName, clipId)
    }
  }

  async doAddToGroup(groupName, clipId) {
    try {
      const res = await fetch('/api/group/' + encodeURIComponent(groupName) + '/add', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ clip_id: clipId })
      })
      if (res.ok) {
        this.fetchAndRender()
        this.dispatchGroupsRefresh()
        this.showSuccess('Added to group')
      } else {
        this.showError('Failed to add clip to group')
      }
    } catch (err) {
      this.showError('Failed to add clip to group')
    }
  }

  async removeFromGroup(clipId) {
    try {
      const res = await fetch('/api/group/' + encodeURIComponent(this.groupValue) + '/remove', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ clip_id: clipId })
      })
      if (res.ok) {
        this.selectedClipIdValue = ''
        this.resetEditor()
        this.fetchAndRender()
        this.dispatchGroupsRefresh()
        this.showSuccess('Removed from group')
      } else {
        this.showError('Failed to remove clip from group')
      }
    } catch (err) {
      this.showError('Failed to remove clip from group')
    }
  }

  setFilter(event) {
    this.filterValue = event.currentTarget.value
  }

  dispatchGroupsRefresh() {
    this.element.dispatchEvent(new CustomEvent('groups:refresh', { bubbles: true }))
  }

  renderStarsDisplay(rating) {
    let html = ''
    for (let i = 1; i <= 5; i++) {
      html += '<span class="' + (i <= rating ? 'text-accent' : 'text-star-empty') + '">★</span>'
    }
    return html
  }
}
