import ApplicationController from './application_controller.js'
import { renderIcons } from '../../frontend/icons.js'

export default class extends ApplicationController {
  static targets = ['grid', 'newGroupCard', 'newGroupForm', 'newGroupInput', 'archiveTab', 'search', 'sort']

  connect() {
    this.groupStats = []
    this.archived = false
    this.onRefresh = event => {
      if (event?.detail?.source === 'group-manager') return
      if (this.getNavState().view === 'groups') this.fetchAndRender()
    }
    this.onOutsideClick = event => {
      this.gridTarget.querySelectorAll('.compilation-menu[open]').forEach(menu => {
        if (!menu.contains(event.target)) menu.open = false
      })
    }
    document.addEventListener('click', this.onOutsideClick)
    this.onEdit = async event => {
      try {
        await this.fetchGroupStats()
        const group = this.groupStats.find(item => item.name === event.detail.name)
        if (group) this.editDetails(group)
      } catch (error) { this.showError(error.message) }
    }
    document.addEventListener('groups:refresh', this.onRefresh)
    document.addEventListener('nav:changed', this.onRefresh)
    document.addEventListener('compilation:edit', this.onEdit)
    if (this.getNavState().view === 'groups') this.fetchAndRender()
  }

  disconnect() {
    document.removeEventListener('groups:refresh', this.onRefresh)
    document.removeEventListener('nav:changed', this.onRefresh)
    document.removeEventListener('compilation:edit', this.onEdit)
    document.removeEventListener('click', this.onOutsideClick)
    this.dialog?.close()
  }

  async fetchGroupStats() {
    const request = this.statsRequest = (this.statsRequest || 0) + 1
    const groups = await this.fetchJson('/api/groups/stats')
    if (request === this.statsRequest) this.groupStats = groups
  }

  async fetchAndRender() {
    try { await this.fetchGroupStats(); this.render() }
    catch (error) { this.showError('Could not load compilations: ' + error.message) }
  }

  render() {
    this.gridTarget.querySelectorAll('.group-card, .group-grid-empty').forEach(node => node.remove())
    this.archiveTabTargets.forEach(tab => {
      const archived = tab.dataset.archived === 'true'
      tab.setAttribute('aria-pressed', String(archived === this.archived))
      tab.textContent = `${archived ? 'Archived' : 'Active'} (${this.groupStats.filter(group => Boolean(group.archived) === archived).length})`
    })
    this.sortTarget.querySelector('[value="archived"]').hidden = !this.archived
    const query = this.searchTarget.value.trim()
    const groups = this.visibleGroups()
    if (!groups.length) {
      const empty = document.createElement('div')
      empty.className = 'group-grid-empty'
      empty.textContent = query ? 'No compilations match your search.' : this.archived
        ? 'Finished projects live here. Archive a compilation when you’re done; you can restore it at any time.'
        : 'Build your next video: create a compilation, then add clips from the library.'
      const action = this.makeButton(query ? 'Clear search' : this.archived ? 'View active compilations' : '+ New compilation', () => {
        if (query) { this.searchTarget.value = ''; this.render() }
        else if (this.archived) { this.archived = false; this.sortTarget.value = 'updated'; this.render() }
        else this.showNewGroupForm()
      })
      empty.append(action)
      this.gridTarget.append(empty)
    }
    groups.forEach(group => this.gridTarget.append(this.makeCard(group)))
  }

  visibleGroups() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    const groups = this.groupStats.filter(group => Boolean(group.archived) === this.archived &&
      `${group.name} ${group.description || ''}`.toLocaleLowerCase().includes(query))
    groups.sort((a, b) => {
      if (this.sortTarget.value === 'name') return a.name.localeCompare(b.name, undefined, { numeric: true })
      const field = this.sortTarget.value === 'archived' ? 'archived_at' : 'updated_at'
      return (b[field] || '').localeCompare(a[field] || '') || a.name.localeCompare(b.name)
    })
    return groups
  }

  makeButton(label, callback, className = '') {
    const button = document.createElement('button')
    button.type = 'button'
    button.textContent = label
    button.className = className
    button.addEventListener('click', callback)
    return button
  }

  makeCard(group) {
    const card = document.createElement('article')
    card.className = 'group-card compilation-card'
    card.dataset.group = group.name
    const image = group.cover_url || group.thumbnail_url
    card.innerHTML = `<div class="compilation-art" aria-hidden="true"></div>
      <div class="compilation-card-content">
        <div class="compilation-card-top"><span class="compilation-kind"><i data-lucide="film"></i> Compilation</span></div>
        <button type="button" class="compilation-title"></button>
        <div class="compilation-stats"></div>
        <p class="compilation-description"></p>
        <div class="compilation-card-bottom"></div>
      </div>`
    if (image) {
      const img = document.createElement('img')
      img.src = image; img.alt = ''; img.loading = 'lazy'
      img.addEventListener('error', () => img.remove())
      card.querySelector('.compilation-art').append(img)
    }
    const title = card.querySelector('.compilation-title')
    title.textContent = group.name
    title.title = group.name
    title.addEventListener('click', () => this.openGroup(group.name))
    card.addEventListener('click', event => {
      if (!event.target.closest('button, a, details')) this.openGroup(group.name)
    })
    card.querySelector('.compilation-stats').textContent = `${group.clip_count} ${group.clip_count === 1 ? 'clip' : 'clips'} · ${this.formatDuration(group.total_duration)} total`
    const description = card.querySelector('.compilation-description')
    description.textContent = group.description || ''; description.hidden = !group.description
    const bottom = card.querySelector('.compilation-card-bottom')
    if (group.youtube_url) {
      const link = document.createElement('a')
      link.href = group.youtube_url; link.target = '_blank'; link.rel = 'noopener noreferrer'
      link.textContent = 'Watch on YouTube ↗'; link.title = 'YouTube linked — open finished video'
      bottom.append(link)
    }
    if (group.archived_at) {
      const date = document.createElement('span')
      date.textContent = 'Archived ' + new Date(group.archived_at).toLocaleDateString()
      bottom.append(date)
    }
    const menu = document.createElement('details')
    menu.className = 'compilation-menu'
    menu.addEventListener('keydown', event => {
      if (event.key === 'Escape') { menu.open = false; menu.querySelector('summary').focus() }
    })
    const summary = document.createElement('summary')
    summary.textContent = '⋯'; summary.setAttribute('aria-label', 'Actions for ' + group.name)
    menu.append(summary)
    const actions = document.createElement('div')
    actions.append(this.makeButton('Edit details…', () => { menu.open = false; this.editDetails(group) }),
      this.makeButton(group.archived ? 'Restore to active' : 'Archive…', () => {
        menu.open = false
        if (group.archived) this.restore(group)
        else this.editDetails(group, true)
      }), this.makeButton('Delete compilation…', () => { menu.open = false; this.deleteGroup(group) }, 'compilation-delete'))
    menu.append(actions)
    menu.addEventListener('toggle', () => {
      if (menu.open) this.gridTarget.querySelectorAll('details[open]').forEach(other => { if (other !== menu) other.open = false })
    })
    card.querySelector('.compilation-card-top').append(menu)
    renderIcons(card)
    return card
  }

  switchArchive(event) {
    this.archived = event.currentTarget.dataset.archived === 'true'
    this.sortTarget.value = this.archived ? 'archived' : 'updated'
    this.render()
  }

  openGroup(name) { this.navigateTo({ view: 'group-detail', group: name, clipId: '' }) }

  showNewGroupForm() {
    this.newGroupFormTarget.hidden = false
    this.newGroupInputTarget.focus()
  }

  cancelNewGroupForm() {
    this.newGroupFormTarget.hidden = true
    this.newGroupInputTarget.value = ''
  }

  async createGroup(event) {
    event.preventDefault()
    const name = this.newGroupInputTarget.value.trim()
    if (!name) return
    const button = this.newGroupFormTarget.querySelector('[type="submit"]')
    button.disabled = true
    try {
      await this.fetchJson('/api/groups', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name }) })
      this.cancelNewGroupForm()
      this.archived = false; this.searchTarget.value = ''; this.sortTarget.value = 'updated'
      await this.refresh()
      this.showSuccess('Compilation created')
    } catch (error) { this.showError(error.message) }
    finally { button.disabled = false }
  }

  async update(name, changes) {
    return this.fetchJson('/api/groups/' + encodeURIComponent(name), {
      method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(changes)
    })
  }

  async refresh() {
    await this.fetchAndRender()
    document.dispatchEvent(new CustomEvent('groups:refresh', { detail: { source: 'group-manager' } }))
  }

  async restore(group) {
    try { await this.update(group.name, { archived: false }); await this.refresh(); this.showSuccess('Compilation restored to active') }
    catch (error) { this.showError(error.message) }
  }

  async deleteGroup(group) {
    if (!confirm(`Delete compilation "${group.name}"? Its cover and publication details will be removed. Clips will not be deleted.`)) return
    try {
      await this.fetchJson('/api/groups/' + encodeURIComponent(group.name), { method: 'DELETE' })
      await this.refresh()
      this.showSuccess('Compilation deleted')
    } catch (error) { this.showError(error.message) }
  }

  editDetails(group, archive = false) {
    if (this.dialog?.open) return
    const dialog = document.createElement('dialog')
    this.dialog = dialog
    dialog.className = 'compilation-dialog'
    dialog.setAttribute('aria-labelledby', 'compilation-dialog-heading')
    dialog.innerHTML = `<form>
      <h2 id="compilation-dialog-heading">${archive ? 'Archive compilation' : 'Compilation details'}</h2>
      <p>${archive ? 'Keep a record of the finished video. YouTube link and thumbnail are optional; you can restore this project later.' : 'Organize your video project and its publication details.'}</p>
      <label>Title<input name="name" required maxlength="100" autocomplete="off"></label>
      <label>Description<textarea name="description" maxlength="5000" rows="3"></textarea></label>
      <label>YouTube video link <span>(optional)</span><input name="youtube" type="url" maxlength="2048" placeholder="https://www.youtube.com/watch?v=…"></label>
      <label>Cover image <span>(optional · PNG, JPEG or WebP · up to 10 MB)</span><input name="cover" type="file" accept="image/png,image/jpeg,image/webp"></label>
      <button type="button" class="compilation-cover-preview" title="Enlarge cover" hidden><img alt="Compilation cover preview"></button>
      <button type="button" class="compilation-remove-cover" hidden>Remove custom cover</button>
      <p class="compilation-dialog-status" role="status"></p>
      <div class="compilation-dialog-actions"><button type="button" class="cancel">Cancel</button><button type="submit" class="compilation-create">${archive ? 'Save & archive' : 'Save changes'}</button></div>
    </form>`
    const form = dialog.querySelector('form')
    const fields = form.elements
    fields.name.value = group.name
    fields.description.value = group.description || ''
    fields.youtube.value = group.youtube_url || ''
    const status = dialog.querySelector('[role="status"]')
    const preview = dialog.querySelector('.compilation-cover-preview')
    const remove = dialog.querySelector('.compilation-remove-cover')
    let removeCover = false
    let objectUrl = null
    const showPreview = url => {
      preview.hidden = !url
      if (url) preview.querySelector('img').src = url
      else preview.querySelector('img').removeAttribute('src')
    }
    showPreview(group.cover_url || group.thumbnail_url)
    remove.hidden = !group.cover_url
    preview.addEventListener('click', () => this.enlargeCover(preview.querySelector('img').src))
    fields.cover.addEventListener('change', () => {
      const file = fields.cover.files[0]
      if (objectUrl) URL.revokeObjectURL(objectUrl)
      objectUrl = null
      if (file && (file.size > 10 * 1024 * 1024 || !['image/png', 'image/jpeg', 'image/webp'].includes(file.type))) {
        status.textContent = 'Choose a PNG, JPEG or WebP image up to 10 MB.'
        fields.cover.value = ''
      } else { status.textContent = ''; if (file) { objectUrl = URL.createObjectURL(file); removeCover = false } }
      showPreview(objectUrl || (removeCover ? group.thumbnail_url : group.cover_url || group.thumbnail_url))
      remove.hidden = !objectUrl && (!group.cover_url || removeCover)
    })
    remove.addEventListener('click', () => {
      removeCover = true; fields.cover.value = ''
      if (objectUrl) URL.revokeObjectURL(objectUrl)
      objectUrl = null; remove.hidden = true
      showPreview(group.thumbnail_url)
    })
    dialog.querySelector('.cancel').addEventListener('click', () => dialog.close())
    let saving = false
    dialog.addEventListener('cancel', event => { if (saving) event.preventDefault() })
    dialog.addEventListener('close', () => {
      if (objectUrl) URL.revokeObjectURL(objectUrl)
      dialog.remove(); this.dialog = null
    }, { once: true })
    form.addEventListener('submit', async event => {
      event.preventDefault()
      if (saving) return
      const name = fields.name.value.trim()
      if (!name) { fields.name.focus(); return }
      const changes = { description: fields.description.value, youtube_url: fields.youtube.value.trim() }
      const file = fields.cover.files[0]
      saving = true
      const controls = Array.from(form.querySelectorAll('input, textarea, button'))
      controls.forEach(control => { control.disabled = true })
      status.textContent = 'Saving…'
      try {
        // Save publication fields before archiving so a failed upload leaves the project active.
        await this.update(group.name, changes)
        const coverUrl = '/api/groups/' + encodeURIComponent(group.name) + '/cover'
        if (file) {
          const body = new FormData(); body.append('image', file)
          await this.fetchJson(coverUrl, { method: 'POST', body })
        } else if (removeCover) await this.fetchJson(coverUrl, { method: 'DELETE' })
        if (name !== group.name) {
          await this.fetchJson('/api/groups/rename', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ old_name: group.name, new_name: name }) })
          const oldName = group.name
          group.name = name
          if (this.getNavState().group === oldName) this.navigateTo({ group: name }, { replace: true })
        }
        if (archive) await this.update(group.name, { archived: true })
        dialog.close()
        await this.refresh()
        this.showSuccess(archive ? 'Compilation archived' : 'Compilation details saved')
      } catch (error) { status.textContent = 'Could not finish saving: ' + error.message + '. Earlier successful changes were saved; you can retry.' }
      finally { saving = false; controls.forEach(control => { control.disabled = false }) }
    })
    document.body.append(dialog)
    dialog.showModal()
  }

  enlargeCover(url) {
    const viewer = document.createElement('dialog')
    viewer.className = 'compilation-cover-viewer'
    viewer.setAttribute('aria-label', 'Full cover preview')
    const image = document.createElement('img'); image.src = url; image.alt = 'Compilation cover'
    viewer.append(image, this.makeButton('Close preview', () => viewer.close()))
    viewer.addEventListener('close', () => viewer.remove(), { once: true })
    document.body.append(viewer); viewer.showModal()
  }
}
