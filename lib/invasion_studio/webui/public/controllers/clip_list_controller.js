import ApplicationController from "./application_controller.js"
import { DEFAULT_FILTER } from "./router_controller.js"
import { renderIcons } from "../../frontend/icons.js"

export default class extends ApplicationController {
  static targets = ["container", "panelTitle", "filterDropdown", "filterSelect", "sortDropdown", "sortSelect", "groupExport", "uploadButton", "searchControls", "searchInput", "tagFilter", "ratingFilter", "resultFilter", "emptyTrashBtn"]
  static values = {
    view: { type: String, default: "all" },
    filter: { type: String, default: DEFAULT_FILTER },
    sort: { type: String, default: "" },
    q: { type: String, default: "" },
    tag: { type: String, default: "" },
    rating: { type: String, default: "" },
    result: { type: String, default: "" },
    group: { type: String, default: "" },
    selectedClipId: { type: String, default: "" }
  }

  initialize() {
    // Set here (not in connect) so value-changed callbacks that fire during
    // hydration, before connect(), can safely use them.
    this.groups = []
    this.clips = []
  }

  connect() {
    this.onRefresh = () => {
      this.fetchAndRender()
      this.refreshTagOptions()
    }
    this.onKeydown = (event) => this.handleKeyboardShortcut(event)
    this.onUploadComplete = () => this.fetchAndRender()
    this.element.addEventListener('clip-list:refresh', this.onRefresh)
    document.addEventListener('upload:complete', this.onUploadComplete)
    this.fetchGroups().then(() => this.fetchAndRender())
    this.refreshTagOptions()
    document.addEventListener('keydown', this.onKeydown)
  }

  disconnect() {
    this.element.removeEventListener('clip-list:refresh', this.onRefresh)
    document.removeEventListener('upload:complete', this.onUploadComplete)
    document.removeEventListener('keydown', this.onKeydown)
    this.listAbortController?.abort()
    this.selectionAbortController?.abort()
  }

  handleKeyboardShortcut(e) {
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
  }

  selectNextClip(direction) {
    if (this.clips.length === 0) return
    const currentIndex = this.clips.findIndex(c => c.id === this.selectedClipIdValue)
    let nextIndex = currentIndex + direction
    if (nextIndex < 0) nextIndex = this.clips.length - 1
    if (nextIndex >= this.clips.length) nextIndex = 0
    this.selectClip(this.clips[nextIndex].id)
  }

  viewValueChanged() {
    this.fetchAndRender()
  }
  filterValueChanged() {
    this.fetchAndRender()
    if (this.hasFilterSelectTarget) {
      this.filterSelectTarget.value = this.filterValue
    }
  }
  sortValueChanged() {
    this.fetchAndRender()
    if (this.hasSortSelectTarget) {
      this.sortSelectTarget.value = this.sortValue
    }
  }
  qValueChanged() {
    this.fetchAndRender()
    if (this.hasSearchInputTarget && this.searchInputTarget.value.trim() !== this.qValue) {
      this.searchInputTarget.value = this.qValue
    }
  }
  tagValueChanged() {
    this.fetchAndRender()
    if (this.hasTagFilterTarget) {
      this.tagFilterTarget.value = this.tagValue
    }
  }
  ratingValueChanged() {
    this.fetchAndRender()
    if (this.hasRatingFilterTarget) {
      this.ratingFilterTarget.value = this.ratingValue
    }
  }
  resultValueChanged() {
    this.fetchAndRender()
    if (this.hasResultFilterTarget) {
      this.resultFilterTarget.value = this.resultValue
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
    // Load (or clear) the preview here — not in the click handler — so a
    // deep-linked selection hydrated by the router also loads the clip.
    this.loadSelectedClip()
  }

  async loadSelectedClip() {
    if (!this.selectedClipIdValue) {
      this.clearPreview()
      return
    }
    const id = this.selectedClipIdValue
    this.selectionAbortController?.abort()
    this.selectionAbortController = new AbortController()
    let clip
    try {
      clip = await this.fetchJson('/api/clip/' + encodeURIComponent(id), { signal: this.selectionAbortController.signal })
    } catch (error) {
      if (error.name !== 'AbortError') this.clearPreview()
      return
    }
    if (id !== this.selectedClipIdValue) return // stale response, selection moved on
    if (clip.error) {
      this.clearPreview()
      return
    }
    document.getElementById('meta-filename').textContent = clip.filename
    const videoPlayerEl = document.querySelector('[data-controller~="video-player"]')
    if (videoPlayerEl) {
      videoPlayerEl.dataset.videoPlayerClipIdValue = clip.id
      videoPlayerEl.dataset.videoPlayerSrcValue = '/clip/' + encodeURIComponent(clip.filename)
      videoPlayerEl.dataset.videoPlayerCutsValue = JSON.stringify(clip.cuts || [])
    }
    const editorEl = document.querySelector('[data-controller~="editor"]')
    if (editorEl) {
      editorEl.dataset.editorClipIdValue = clip.id
    }
    this.scrollSelectedIntoView()
  }

  clearPreview() {
    document.getElementById('meta-filename').textContent = '—'
    const videoPlayerEl = document.querySelector('[data-controller~="video-player"]')
    if (videoPlayerEl) {
      videoPlayerEl.dataset.videoPlayerClipIdValue = ''
      videoPlayerEl.dataset.videoPlayerSrcValue = ''
      videoPlayerEl.dataset.videoPlayerCutsValue = '[]'
    }
    const editorEl = document.querySelector('[data-controller~="editor"]')
    if (editorEl) {
      editorEl.dataset.editorClipIdValue = ''
    }
  }

  scrollSelectedIntoView() {
    if (!this.selectedClipIdValue) return
    const selectedEl = this.containerTarget.querySelector('[data-id="' + CSS.escape(this.selectedClipIdValue) + '"]')
    if (selectedEl) {
      selectedEl.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
    }
  }

  async fetchGroups() {
    this.groups = await this.fetchJson('/api/groups')
  }

  async fetchAndRender() {
    if (this.viewValue === 'groups') {
      this.containerTarget.innerHTML = ''
      this.updateVisibility()
      return
    }

    const url = this.buildUrl()
    this.listAbortController?.abort()
    this.listAbortController = new AbortController()
    try {
      this.clips = (await this.fetchJson(url, { signal: this.listAbortController.signal })) || []
      this.render()
      this.updateVisibility()
    } catch (e) {
      if (e.name !== 'AbortError') console.error('Error loading clips:', e)
    }
  }

  buildUrl() {
    // Group detail keeps manual drag order and shows the group as-is;
    // search/filter/sort apply to the overview only.
    if (this.groupValue) {
      return '/api/clips?group=' + encodeURIComponent(this.groupValue)
    }
    const params = new URLSearchParams()
    params.set('filter', this.filterValue)
    if (this.qValue) params.set('q', this.qValue)
    if (this.tagValue) params.set('tag', this.tagValue)
    if (this.ratingValue) params.set('rating', this.ratingValue)
    if (this.resultValue) params.set('result', this.resultValue)
    if (this.sortValue) params.set('sort', this.sortValue)
    return '/api/clips?' + params.toString()
  }

  updateVisibility() {
    if (this.viewValue === 'groups') {
      this.containerTarget.style.display = 'none'
      this.filterDropdownTarget.style.display = 'none'
      this.sortDropdownTarget.style.display = 'none'
      this.groupExportTarget.style.display = 'none'
      this.panelTitleTarget.textContent = 'Groups'
    } else if (this.viewValue === 'group-detail') {
      this.containerTarget.style.display = 'block'
      this.filterDropdownTarget.style.display = 'none'
      this.sortDropdownTarget.style.display = 'none'
      this.groupExportTarget.style.display = 'flex'
      this.panelTitleTarget.textContent = this.groupValue + ' (' + this.clips.length + ' clips)'
    } else {
      this.containerTarget.style.display = 'block'
      this.filterDropdownTarget.style.display = 'block'
      this.sortDropdownTarget.style.display = 'block'
      this.groupExportTarget.style.display = 'none'
      const filterLabel = {
        everything: 'Everything',
        unassigned: 'Unassigned',
        assigned: 'Assigned',
        deleted: 'Trash'
      }
      this.panelTitleTarget.textContent = filterLabel[this.filterValue] + ' (' + this.clips.length + ')'
    }
    if (this.hasUploadButtonTarget) {
      this.uploadButtonTarget.style.display = this.viewValue === 'all' ? 'inline-flex' : 'none'
    }
    if (this.hasSearchControlsTarget) {
      this.searchControlsTarget.style.display = this.viewValue === 'all' ? 'flex' : 'none'
    }
    if (this.hasEmptyTrashBtnTarget) {
      const inTrashView = this.viewValue === 'all' && this.filterValue === 'deleted'
      this.emptyTrashBtnTarget.style.display = inTrashView ? 'inline-block' : 'none'
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
      div.className = 'bg-surface border border-border rounded-md mb-2 flex items-center gap-3 overflow-hidden cursor-pointer hover:border-border-active' + (clip.id === this.selectedClipIdValue ? ' bg-surface-hover border-accent' : '')
      div.dataset.index = index
      div.dataset.id = clip.id

      const noteText = clip.note ? clip.note : 'No note'
      const noteClass = clip.note ? '' : ' italic opacity-60'
      const rating = clip.rating || 0
      const displayTitle = clip.title ? clip.title : clip.filename
      const thumbnailImage = clip.thumbnail_url
        ? '<img src="' + this.escapeAttribute(clip.thumbnail_url) + '" class="absolute inset-0 w-full h-full object-cover scale-150" alt="" onerror="this.style.display=\'none\'">'
        : '<div class="absolute inset-0 flex items-center justify-center text-text-muted text-xs">No img</div>'
      const thumbnailHtml = '<div class="relative w-32 self-stretch flex-shrink-0 overflow-hidden bg-surface-secondary">' +
        thumbnailImage + this.renderResultOverlay(clip.result) + '</div>'

      let groupActionHtml = ''
      if (this.filterValue === 'deleted') {
        groupActionHtml = '<button class="bg-transparent border border-text-muted text-text-muted px-3 py-1 text-xs rounded cursor-pointer hover:border-text-primary hover:text-text-primary">Restore</button>'
      } else if (this.viewValue === 'all') {
        const assignedGroups = clip.groups || []
        if (assignedGroups.length > 0) {
          const groupName = this.escapeHtml(assignedGroups[0])
          groupActionHtml = '<div class="group-badge text-xs text-text-muted whitespace-nowrap cursor-pointer underline">' + groupName + '</div>'
        } else {
          const options = this.groups.map(g => '<option value="' + this.escapeAttribute(g.name) + '">' + this.escapeHtml(g.name) + '</option>').join('')
                groupActionHtml = '<select class="w-28 bg-surface-secondary text-text-primary border border-border px-1.5 py-0.5 rounded text-[11px] cursor-pointer"><option value="">Add to group...</option>' + options + '<option value="__new__">+ New Group...</option></select>'
        }
      } else {
        groupActionHtml = '<button class="bg-transparent border border-text-muted text-text-muted px-3 py-1 text-xs rounded cursor-pointer hover:border-text-primary hover:text-text-primary">Remove</button>'
      }

      const dragHandle = (this.viewValue === 'group-detail' && this.filterValue !== 'deleted')
        ? '<span class="text-text-muted cursor-grab text-lg px-1 select-none">&#x2630;</span>'
        : ''

      const tags = clip.tags || []
      const tagsHtml = tags.length
        ? '<div class="flex flex-wrap gap-1 mt-1.5">' + tags.map(tag =>
            '<span class="bg-surface-secondary text-text-muted border border-border px-1.5 py-px rounded-full text-[10px]">' + this.escapeHtml(tag) + '</span>'
          ).join('') + '</div>'
        : ''

      div.innerHTML = thumbnailHtml + dragHandle +
        '<div class="flex-1 min-w-0 py-3.5">' +
        '<div class="font-medium text-sm mb-1 whitespace-nowrap overflow-hidden text-ellipsis">' + this.escapeHtml(displayTitle) + '</div>' +
        '<div class="text-xs text-text-muted whitespace-nowrap overflow-hidden text-ellipsis' + noteClass + '">' + this.escapeHtml(noteText) + '</div>' +
        tagsHtml +
        '</div>' +
        '<div class="flex flex-col gap-1 items-end py-3.5 pr-3.5">' +
        '<div class="inline-flex gap-0.5 text-[1.25rem] leading-none">' + this.renderStarsDisplay(rating) + '</div>' +
        groupActionHtml +
        '</div>'

      renderIcons(div)

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
          this.navigateTo({ view: 'group-detail', group: clip.groups[0], clipId: '' })
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

    // A deep-linked selection may hydrate before the list is rendered —
    // re-run the scroll once the element exists.
    this.scrollSelectedIntoView()
  }

  selectClip(id) {
    // Route through the router: it updates the URL and sets
    // selectedClipIdValue, which triggers loadSelectedClip().
    this.navigateTo({ clipId: id })
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
        // Drop /clips/:id from the URL; clearPreview runs via the callback
        this.navigateTo({ clipId: '' }, { replace: true })
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
    // replace (not push): filter is a refinement, not a navigation Back
    // should step through.
    this.navigateTo({ filter: event.currentTarget.value }, { replace: true })
  }

  setSort(event) {
    // replace, same reasoning as setFilter
    this.navigateTo({ sort: event.currentTarget.value }, { replace: true })
  }

  async emptyTrash() {
    const count = this.clips.length
    if (count === 0) return
    if (!confirm('Permanently delete ' + count + ' clip(s) from the trash? Video files and thumbnails will be removed from disk. This cannot be undone.')) return
    try {
      const data = await this.fetchJson('/api/trash/empty', { method: 'POST' })
      this.showSuccess('Emptied trash: ' + data.purged + ' clip(s) removed.')
      this.navigateTo({ clipId: '' }, { replace: true })
      this.fetchAndRender()
    } catch (e) {
      this.showError('Failed to empty trash')
    }
  }

  setSearch() {
    this.debouncedSearchNavigate ??= this.debounce(() => {
      this.navigateTo({ q: this.searchInputTarget.value.trim() }, { replace: true })
    }, 300)
    this.debouncedSearchNavigate()
  }

  setTagFilter(event) {
    this.navigateTo({ tag: event.currentTarget.value }, { replace: true })
  }

  setRatingFilter(event) {
    this.navigateTo({ rating: event.currentTarget.value }, { replace: true })
  }

  setResultFilter(event) {
    this.navigateTo({ result: event.currentTarget.value }, { replace: true })
  }

  async refreshTagOptions() {
    if (!this.hasTagFilterTarget) return
    try {
      const tags = await this.fetchJson('/api/tags')
      this.tagFilterTarget.innerHTML = '<option value="">All tags</option>' + tags.map(tag =>
        '<option value="' + this.escapeAttribute(tag) + '">' + this.escapeHtml(tag) + '</option>'
      ).join('')
      this.tagFilterTarget.value = this.tagValue
    } catch (e) {
      // The tag filter is optional; the list itself still works without it.
    }
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

  renderResultOverlay(result) {
    const overlays = {
      win: { icon: 'trophy', classes: 'text-white', label: 'Win' },
      loss: { icon: 'circle-x', classes: 'text-white', label: 'Loss' },
      dc: { icon: 'unplug', classes: 'text-white', label: 'DC' }
    }
    const overlay = overlays[result]
    if (!overlay) return ''

    return '<span title="' + overlay.label + '" class="absolute top-1.5 left-1.5 flex size-5 items-center justify-center rounded-full bg-black/85 ' + overlay.classes + '">' +
      '<i data-lucide="' + overlay.icon + '" class="size-3"></i></span>'
  }
}
