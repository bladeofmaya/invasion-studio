import ApplicationController from "./application_controller.js"
import { renderIcons } from "../../frontend/icons.js"

export default class extends ApplicationController {
  static targets = ["overlay", "tab", "panel", "tagList", "storagePanel", "statsPanel", "audioTrackCount", "defaultAudioTrack", "videoStatus", "dependenciesPanel"]

  open() {
    this.overlayTarget.style.display = 'flex'
    this.loadCategory(this.currentCategory || 'tags')
  }

  close() {
    this.overlayTarget.style.display = 'none'
  }

  backdropClose(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  switchCategory(event) {
    const category = event.currentTarget.dataset.category
    this.tabTargets.forEach(tab => {
      const active = tab.dataset.category === category
      tab.classList.toggle('bg-surface-hover', active)
      tab.classList.toggle('bg-transparent', !active)
      tab.classList.toggle('text-text-primary', active)
      tab.classList.toggle('text-text-muted', !active)
    })
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.category !== category
    })
    this.loadCategory(category)
  }

  loadCategory(category) {
    this.currentCategory = category
    if (category === 'dependencies') this.loadDependencies()
    if (category === 'tags') this.loadTags()
    if (category === 'storage') this.loadStorage()
    if (category === 'video') this.loadVideoSettings()
    if (category === 'stats') this.loadStats()
  }

  async loadVideoSettings() {
    try {
      const settings = await this.fetchJson('/api/settings/video')
      this.audioTrackCountTarget.value = settings.audio_track_count
      this.updateDefaultAudioTrackOptions(settings.default_audio_track)
      this.videoStatusTarget.textContent = ''
    } catch (err) {
      this.videoStatusTarget.textContent = 'Failed to load video settings.'
    }
  }

  updateDefaultAudioTrackOptions(selectedTrack = null) {
    const count = Math.max(1, Math.min(32, parseInt(this.audioTrackCountTarget.value, 10) || 1))
    const current = typeof selectedTrack === 'number' ? selectedTrack : parseInt(this.defaultAudioTrackTarget.value, 10)
    this.defaultAudioTrackTarget.innerHTML = Array.from({ length: count }, (_, index) => {
      const track = index + 1
      return '<option value="' + track + '">Track ' + track + '</option>'
    }).join('')
    this.defaultAudioTrackTarget.value = String(Math.min(Math.max(current || 1, 1), count))
  }

  async saveVideoSettings() {
    const audioTrackCount = parseInt(this.audioTrackCountTarget.value, 10)
    const defaultAudioTrack = parseInt(this.defaultAudioTrackTarget.value, 10)
    try {
      const settings = await this.fetchJson('/api/settings/video', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ audio_track_count: audioTrackCount, default_audio_track: defaultAudioTrack })
      })
      this.videoStatusTarget.textContent = 'Saved'
      document.dispatchEvent(new CustomEvent('video-settings:changed', { detail: settings }))
    } catch (err) {
      this.videoStatusTarget.textContent = 'Could not save video settings.'
    }
  }

  async loadTags() {
    try {
      this.tags = await this.fetchJson('/api/tags/details')
      this.renderTags()
    } catch (err) {
      this.tagListTarget.innerHTML = '<div class="text-sm text-text-muted">Failed to load tags.</div>'
    }
  }

  renderTags() {
    if (!this.tags.length) {
      this.tagListTarget.innerHTML = '<div class="text-sm text-text-muted">No tags yet. Add tags to clips in the editor.</div>'
      return
    }
    this.tagListTarget.innerHTML = this.tags.map(tag =>
      '<div class="flex items-center gap-2 bg-surface-secondary border border-border rounded px-3 py-2" data-name="' + this.escapeAttribute(tag.name) + '">' +
      '<span class="text-sm text-text-primary min-w-0 overflow-hidden text-ellipsis whitespace-nowrap">' + this.escapeHtml(tag.name) + '</span>' +
      '<span class="bg-surface text-text-muted border border-border rounded-full px-2 py-0.5 text-xs" title="' + tag.clip_count + ' clip(s) have this tag">' + tag.clip_count + '</span>' +
      '<span class="ml-auto flex gap-1 shrink-0">' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-text-primary hover:bg-surface-hover" title="Rename" aria-label="Rename" data-action="click->settings#startRename"><i data-lucide="pencil" class="size-3.5"></i></button>' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-danger hover:bg-surface-hover" title="Delete" aria-label="Delete" data-action="click->settings#deleteTag"><i data-lucide="trash-2" class="size-3.5"></i></button>' +
      '</span>' +
      '</div>'
    ).join('')
    renderIcons(this.tagListTarget)
  }

  startRename(event) {
    const row = event.currentTarget.closest('[data-name]')
    row.innerHTML =
      '<input type="text" class="bg-input-bg text-text-primary border border-input-border px-2 py-1 rounded text-sm min-w-0 flex-1 focus:outline-none focus:border-input-focus-ring" value="' + this.escapeAttribute(row.dataset.name) + '" data-action="keydown->settings#renameKeydown">' +
      '<span class="ml-auto flex gap-1 shrink-0">' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-success hover:bg-surface-hover" title="Save" aria-label="Save" data-action="click->settings#saveRename"><i data-lucide="check" class="size-3.5"></i></button>' +
      '<button type="button" class="inline-flex items-center justify-center bg-transparent border-none text-text-muted p-1 rounded cursor-pointer hover:text-danger hover:bg-surface-hover" title="Cancel" aria-label="Cancel" data-action="click->settings#cancelRename"><i data-lucide="x" class="size-3.5"></i></button>' +
      '</span>'
    renderIcons(row)
    const input = row.querySelector('input')
    input.focus()
    input.select()
  }

  renameKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      this.saveRename(event)
    } else if (event.key === 'Escape') {
      event.preventDefault()
      this.renderTags()
    }
  }

  cancelRename() {
    this.renderTags()
  }

  async saveRename(event) {
    const row = event.currentTarget.closest('[data-name]')
    const oldName = row.dataset.name
    const newName = row.querySelector('input').value.trim()
    if (!newName || newName === oldName) {
      this.renderTags()
      return
    }
    try {
      const res = await fetch('/api/tags/rename', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ old_name: oldName, new_name: newName })
      })
      if (res.ok) {
        this.showSuccess('Tag renamed')
        this.notifyTagsChanged()
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to rename tag')
      }
    } catch (err) {
      this.showError('Failed to rename tag')
    }
    this.loadTags()
  }

  async deleteTag(event) {
    const row = event.currentTarget.closest('[data-name]')
    const name = row.dataset.name
    const tag = (this.tags || []).find(t => t.name === name)
    const count = tag ? tag.clip_count : 0
    if (!confirm('Delete tag "' + name + '"? It will be removed from ' + count + ' clip(s). This cannot be undone.')) return
    try {
      const res = await fetch('/api/tags/' + encodeURIComponent(name), { method: 'DELETE' })
      if (res.ok) {
        this.showSuccess('Tag deleted')
        this.notifyTagsChanged()
      } else {
        const data = await res.json()
        this.showError(data.error || 'Failed to delete tag')
      }
    } catch (err) {
      this.showError('Failed to delete tag')
    }
    this.loadTags()
  }

  // The clip list re-fetches (which also refreshes its tag filter options);
  // the editor reloads the selected clip's chips and its suggestions.
  notifyTagsChanged() {
    document.dispatchEvent(new CustomEvent('tags:changed'))
    document.getElementById('clip-panel')?.dispatchEvent(new CustomEvent('clip-list:refresh'))
  }

  async loadStorage() {
    try {
      this.storage = await this.fetchJson('/api/storage/stats')
      this.renderStorage()
    } catch (err) {
      this.storagePanelTarget.innerHTML = '<div class="text-sm text-text-muted">Failed to load storage overview.</div>'
    }
  }

  async loadStats() {
    try {
      this.stats = await this.fetchJson('/api/game/stats')
      this.renderStats()
    } catch (err) {
      this.statsPanelTarget.innerHTML = '<div class="text-sm text-text-muted">Failed to load game statistics.</div>'
    }
  }

  renderStats() {
    const s = this.stats
    const winRate = s.win_rate == null ? '—' : this.formatPercentage(s.win_rate)
    this.statsPanelTarget.innerHTML =
      '<div class="grid grid-cols-3 gap-3 mb-5">' +
      this.statCard('Invasions', s.invasions) +
      this.statCard('Time in invasions', this.formatDuration(s.duration_seconds)) +
      this.statCard('Win rate', winRate, 'DCs excluded') +
      '</div>' +
      '<div class="mb-1.5 text-xs font-semibold text-text-muted uppercase tracking-wide">Results</div>' +
      '<div class="bg-surface-secondary border border-border rounded-lg divide-y divide-border">' +
      this.statRow('Won', s.results.won) +
      this.statRow('Lost', s.results.lost) +
      this.statRow('Disconnected', s.results.dc) +
      this.statRow('No result', s.results.no_result) +
      '</div>'
  }

  statCard(label, value, note) {
    return '<div class="bg-surface-secondary border border-border rounded-lg p-3 min-w-0">' +
      '<div class="text-xs text-text-muted mb-1">' + label + '</div>' +
      '<div class="text-xl font-semibold text-text-primary truncate">' + value + '</div>' +
      (note ? '<div class="text-[10px] text-text-muted mt-1">' + note + '</div>' : '') +
      '</div>'
  }

  statRow(label, value) {
    return '<div class="flex items-center px-3 py-2.5">' +
      '<span class="text-sm text-text-primary">' + label + '</span>' +
      '<span class="ml-auto text-sm font-semibold text-text-primary">' + value + '</span>' +
      '</div>'
  }

  formatPercentage(value) {
    return Number(value).toLocaleString(undefined, { maximumFractionDigits: 1 }) + '%'
  }

  renderStorage() {
    const s = this.storage
    const segments = [
      { label: 'Clips', bytes: s.clips.bytes, color: 'bg-primary' },
      { label: 'Thumbnails', bytes: s.thumbnails.bytes, color: 'bg-success' },
      { label: 'Compilation covers', bytes: s.covers.bytes, color: 'bg-accent' },
      { label: 'Exports', bytes: s.exports.bytes, color: 'bg-secondary' },
      { label: 'Trash', bytes: s.trash.bytes, color: 'bg-danger' },
      { label: 'Preview cache', bytes: s.preview_cache.bytes, color: 'bg-star-empty' },
      { label: 'Shared OCR cache', bytes: s.ocr_cache.bytes, color: 'bg-accent' },
      { label: 'Database', bytes: s.database.bytes, color: 'bg-border' }
    ]
    const total = Math.max(s.total_bytes, 1)
    const bar = segments
      .filter(seg => seg.bytes / total >= 0.005)
      .map(seg => '<div class="' + seg.color + '" style="width:' + ((seg.bytes / total) * 100).toFixed(2) + '%"></div>')
      .join('')
    const legend = segments.map(seg =>
      '<span class="inline-flex items-center gap-1.5 text-xs text-text-muted">' +
      '<span class="size-2.5 rounded-full ' + seg.color + '"></span>' + seg.label + '</span>'
    ).join('')

    this.storagePanelTarget.innerHTML =
      this.projectLocation() +
      '<div class="mb-1 flex items-baseline justify-between">' +
      '<span class="text-sm font-semibold text-text-primary">Storage (including shared OCR cache)</span>' +
      '<span class="text-sm text-text-muted">' + this.formatBytes(s.total_bytes) + '</span>' +
      '</div>' +
      '<div class="h-3 rounded-full overflow-hidden flex bg-surface-secondary border border-border">' + bar + '</div>' +
      '<div class="mt-2 flex flex-wrap gap-x-3 gap-y-1">' + legend + '</div>' +

      this.storageSection('Media', [
      this.storageRow('Clips', s.clips.count + ' file(s) · ' + this.formatBytes(s.clips.bytes)),
      this.storageRow('Footage', this.formatDuration(s.clips.duration_seconds)),
      this.storageRow('Thumbnails', s.thumbnails.count + ' file(s) · ' + this.formatBytes(s.thumbnails.bytes)),
      this.storageRow('Compilation covers', s.covers.count + ' file(s) · ' + this.formatBytes(s.covers.bytes)),
      this.storageRow('Exports', s.exports.count + ' file(s) · ' + this.formatBytes(s.exports.bytes)),
      this.storageRow('Database', this.formatBytes(s.database.bytes))
      ]) +

      this.cacheSection('preview', 'Preview cache — this project', s.preview_cache, 'Generated video previews. Rebuilt when needed.') +
      this.cacheSection('ocr', 'OCR cache — all projects', s.ocr_cache, 'Cached recording detection. Clearing requires rescanning recordings next time.') +
      this.storageSection('Maintenance', [
      this.storageRow('Trash', s.trash.count + ' file(s) · ' + this.formatBytes(s.trash.bytes),
        '<button type="button" class="bg-danger text-danger-fg border-none px-3 py-1 text-xs rounded cursor-pointer hover:bg-danger-hover" data-action="click->settings#emptyTrash">Empty Trash</button>')
      ])
  }

  projectLocation() {
    const openButton = window.invasionStudioStorage?.openProjectFolder
      ? '<button type="button" class="mt-2 text-sm text-primary cursor-pointer" data-action="click->settings#openProjectFolder">Open project folder</button>'
      : ''
    return '<div class="mb-5"><div class="text-sm font-semibold mb-1">Project folder</div>' +
      '<div class="text-sm text-text-secondary select-text break-all whitespace-pre-wrap">' +
      this.escapeHtml(this.storage.project_path || '') + '</div>' + openButton + '</div>'
  }

  async openProjectFolder() {
    try {
      await window.invasionStudioStorage?.openProjectFolder()
    } catch (error) {
      this.showError(error.message)
    }
  }

  storageSection(title, rows) {
    return '<div class="mt-5 mb-1.5 text-xs font-semibold text-text-muted uppercase tracking-wide">' + title + '</div>' +
      '<div class="bg-surface-secondary border border-border rounded-lg divide-y divide-border">' + rows.join('') + '</div>'
  }

  storageRow(label, value, action) {
    return '<div class="flex items-center gap-3 px-3 py-2.5">' +
      '<span class="text-sm text-text-primary">' + label + '</span>' +
      '<span class="ml-auto text-sm text-text-muted">' + value + '</span>' +
      (action || '') +
      '</div>'
  }

  cacheSection(scope, title, cache, description) {
    return '<section class="mt-5 border border-border rounded-lg p-3">' +
      '<h4 class="m-0 text-sm font-semibold">' + title + '</h4>' +
      '<p class="text-xs text-text-muted">' + description + '</p>' +
      '<p class="text-xs select-text break-all">' + this.escapeHtml(cache.path) + '</p>' +
      '<div class="flex items-center justify-between gap-2 text-sm">' + cache.count + ' file(s) · ' + this.formatBytes(cache.bytes) +
      '<button type="button" class="border border-border rounded px-3 py-1 cursor-pointer" data-scope="' + scope + '" data-action="click->settings#clearCache">Clear</button></div></section>'
  }

  async clearCache(event) {
    const scope = event.currentTarget.dataset.scope
    if (scope === 'ocr' && !confirm('Clear cached OCR results for all projects? Recordings will need to be scanned again.')) return
    try {
      const data = await this.fetchJson('/api/storage/clear-cache', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ scope })
      })
      this.showSuccess((scope === 'ocr' ? 'OCR' : 'Preview') + ' cache cleared (' + this.formatBytes(data.freed_bytes) + ' freed)')
    } catch (err) {
      this.showError(err.message)
    }
    this.loadStorage()
  }

  async loadDependencies() {
    try {
      this.dependencies = await this.fetchJson('/api/settings/dependencies')
      this.renderDependencies()
    } catch (error) {
      this.dependenciesPanelTarget.textContent = error.message
    }
  }

  renderDependencies() {
    this.dependenciesPanelTarget.innerHTML =
      '<p class="text-sm text-text-muted mt-0">Custom paths apply to new tool invocations across projects on this computer. Leave a field empty to use automatic detection. Paths are checked for availability, not executed here.</p>' +
      this.dependencies.tools.map(tool => `
        <form class="border border-border rounded-lg p-3 mb-4" data-tool="${this.escapeAttribute(tool.name)}" data-action="submit->settings#saveDependency">
          <h4 class="m-0 mb-2 text-sm font-semibold">${this.escapeHtml(tool.name)} — ${tool.available ? 'Available' : 'Unavailable'}</h4>
          <p class="text-xs text-text-muted">Active (${this.escapeHtml(tool.source)}): <span class="select-text break-all">${this.escapeHtml(tool.active_path || 'Not found')}</span></p>
          <p class="text-xs text-text-muted">Detected default: <span class="select-text break-all">${this.escapeHtml(tool.detected_path || 'Not found')}</span></p>
          <label class="block text-sm">Custom executable path
            <input type="text" value="${this.escapeAttribute(tool.custom_path)}" placeholder="Use detected executable" spellcheck="false" class="block w-full bg-input-bg text-text-primary border border-input-border rounded px-2 py-1 mt-1">
          </label>
          <div class="flex gap-3 mt-3">
            <button type="submit" class="text-sm text-primary cursor-pointer">Apply</button>
            <button type="button" class="text-sm text-text-muted cursor-pointer" data-action="click->settings#resetDependency">Use detected</button>
          </div>
          <p class="dependency-status text-xs text-text-muted" role="status"></p>
        </form>`).join('')
  }

  resetDependency(event) {
    const form = event.currentTarget.closest('form')
    form.querySelector('input').value = ''
    form.requestSubmit()
  }

  async saveDependency(event) {
    event.preventDefault()
    const form = event.currentTarget
    const status = form.querySelector('.dependency-status')
    status.textContent = 'Applying…'
    try {
      this.dependencies = await this.fetchJson('/api/settings/dependencies', {
        method: 'PUT', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ [form.dataset.tool]: form.querySelector('input').value })
      })
      this.renderDependencies()
    } catch (error) {
      status.textContent = error.message
    }
  }

  async emptyTrash() {
    const count = this.storage?.trash?.count || 0
    if (count === 0) return
    if (!confirm('Permanently delete ' + count + ' file(s) from the trash? This cannot be undone.')) return
    try {
      const data = await this.fetchJson('/api/trash/empty', { method: 'POST' })
      this.showSuccess('Emptied trash: ' + data.purged + ' clip(s) removed.')
      document.getElementById('clip-panel')?.dispatchEvent(new CustomEvent('clip-list:refresh'))
    } catch (err) {
      this.showError('Failed to empty trash')
    }
    this.loadStorage()
  }

  formatBytes(bytes) {
    if (!bytes) return '0 B'
    const units = ['B', 'KB', 'MB', 'GB', 'TB']
    const exponent = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
    const value = bytes / Math.pow(1024, exponent)
    return (exponent === 0 ? value : value.toFixed(1)) + ' ' + units[exponent]
  }

  formatDuration(seconds) {
    const total = Math.round(seconds || 0)
    const hours = Math.floor(total / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    if (hours === 0 && minutes === 0) return total + ' sec'
    if (hours === 0) return minutes + ' min'
    return hours + ' h ' + minutes + ' min'
  }
}
