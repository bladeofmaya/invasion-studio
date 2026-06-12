let currentView = 'all';
let selectedGroup = null;
let selectedClipId = null;
let filterMode = 'everything';
let allClips = [];
let clips = [];
let groups = [];
let groupStats = [];

async function init() {
    await loadGroups();
    await loadGroupStats();
    await loadClips();
}

async function loadGroups() {
    const res = await fetch('/api/groups');
    groups = await res.json();
}

async function loadGroupStats() {
    const res = await fetch('/api/groups/stats');
    groupStats = await res.json();
}

async function loadClips() {
    const url = selectedGroup ?
        '/api/clips?group=' + encodeURIComponent(selectedGroup) :
        '/api/clips?all=true';
    try {
        const res = await fetch(url);
        if (!res.ok) {
            console.error('Failed to load clips:', res.status);
            return;
        }
        allClips = await res.json();
        applyFilter();
    } catch (e) {
        console.error('Error loading clips:', e);
    }
}

function applyFilter() {
    if (filterMode === 'deleted') {
        clips = allClips.filter(c => c.deleted);
    } else if (filterMode === 'unassigned') {
        const assignedIds = new Set();
        groups.forEach(g => g.clip_ids.forEach(id => assignedIds.add(id)));
        clips = allClips.filter(c => !c.deleted && !assignedIds.has(c.id));
    } else if (filterMode === 'assigned') {
        const assignedIds = new Set();
        groups.forEach(g => g.clip_ids.forEach(id => assignedIds.add(id)));
        clips = allClips.filter(c => !c.deleted && assignedIds.has(c.id));
    } else {
        clips = allClips.filter(c => !c.deleted);
    }
    renderClips();
    updateTitle();
}

function switchView(view) {
    currentView = view;
    selectedGroup = null;
    selectedClipId = null;
    filterMode = 'everything';
    const filterSelect = document.getElementById('clip-filter');
    if (filterSelect) filterSelect.value = 'everything';
    resetEditor();
    updateTabs();
    updateUIVisibility();

    if (view === 'all') {
        loadClips();
    } else if (view === 'groups') {
        loadGroupStats();
        renderGroups();
    }
}

function openGroup(groupName) {
    selectedGroup = groupName;
    currentView = 'group-detail';
    selectedClipId = null;
    resetEditor();
    updateTabs();
    updateUIVisibility();
    loadClips();
}

function goBack() {
    if (currentView === 'group-detail') {
        switchView('groups');
    }
}

function updateTabs() {
    document.querySelectorAll('.tab').forEach((tab, index) => {
        const tabView = index === 0 ? 'all' : 'groups';
        const isActive = (currentView === 'all' && tabView === 'all') ||
            (currentView === 'groups' && tabView === 'groups') ||
            (currentView === 'group-detail' && tabView === 'groups');
        tab.classList.toggle('active', isActive);
    });
}

function updateUIVisibility() {
    const backBtn = document.getElementById('back-btn');
    const clipList = document.getElementById('clip-list');
    const groupGrid = document.getElementById('group-grid');
    const filterDropdown = document.getElementById('filter-dropdown');
    const groupExport = document.getElementById('group-export-controls');
    const previewPanel = document.getElementById('preview-panel');
    const newGroupCard = document.getElementById('new-group-card');
    const newGroupForm = document.getElementById('new-group-inline-form');

    if (currentView === 'groups') {
        if (backBtn) backBtn.style.display = 'none';
        if (clipList) clipList.style.display = 'none';
        if (groupGrid) groupGrid.style.display = 'grid';
        if (filterDropdown) filterDropdown.style.display = 'none';
        if (groupExport) groupExport.style.display = 'none';
        if (newGroupCard) newGroupCard.style.display = 'flex';
        if (previewPanel) previewPanel.style.display = 'none';
    } else if (currentView === 'group-detail') {
        if (backBtn) backBtn.style.display = 'inline-block';
        if (clipList) clipList.style.display = 'block';
        if (groupGrid) groupGrid.style.display = 'none';
        if (filterDropdown) filterDropdown.style.display = 'none';
        if (groupExport) groupExport.style.display = 'flex';
        if (previewPanel) previewPanel.style.display = 'flex';
    } else {
        if (backBtn) backBtn.style.display = 'none';
        if (clipList) clipList.style.display = 'block';
        if (groupGrid) groupGrid.style.display = 'none';
        if (filterDropdown) filterDropdown.style.display = 'block';
        if (groupExport) groupExport.style.display = 'none';
        if (previewPanel) previewPanel.style.display = 'flex';
    }
}

function updateTitle() {
    const title = document.getElementById('panel-title');
    if (currentView === 'group-detail') {
        title.textContent = selectedGroup + ' (' + clips.length + ' clips)';
    } else if (currentView === 'all') {
        const filterLabel = {
            everything: 'Everything',
            unassigned: 'Unassigned',
            assigned: 'Assigned',
            deleted: 'Deleted'
        };
        title.textContent = filterLabel[filterMode] + ' (' + clips.length + ')';
    } else {
        title.textContent = 'Groups';
    }
}

function renderGroups() {
    const grid = document.getElementById('group-grid');
    // Preserve the new group card and form
    const newGroupCard = document.getElementById('new-group-card');
    const newGroupForm = document.getElementById('new-group-inline-form');

    // Remove all group cards but keep the new group elements
    const cards = grid.querySelectorAll('.group-card:not(.new-group-card)');
    cards.forEach(c => c.remove());

    if (groups.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = 'No groups yet. Create one!';
        grid.appendChild(empty);
        return;
    }

    groupStats.forEach(stat => {
        const card = document.createElement('div');
        card.className = 'group-card';
        card.onclick = (e) => {
            if (e.target.tagName === 'BUTTON' || e.target.tagName === 'INPUT') return;
            openGroup(stat.name);
        };

        const duration = formatDuration(stat.total_duration);
        card.innerHTML =
            '<div class="name">' + escapeHtml(stat.name) + '</div>' +
            '<div class="stats">' +
            '<span>' + stat.clip_count + '</span> clips &middot; <span>' + duration + '</span> total' +
            '</div>' +
            '<div class="actions">' +
            '<button class="secondary" onclick="event.stopPropagation(); startRenameCard(this, \'' + escapeHtml(stat.name) + '\')">Rename</button>' +
            '<button class="danger" onclick="event.stopPropagation(); deleteGroup(\'' + escapeHtml(stat.name) + '\')">Delete</button>' +
            '</div>';
        grid.appendChild(card);
    });
}

function startRenameCard(btn, oldName) {
    const card = btn.closest('.group-card');
    const nameDiv = card.querySelector('.name');

    const wrapper = document.createElement('div');
    wrapper.style.display = 'flex';
    wrapper.style.gap = '8px';
    wrapper.style.alignItems = 'center';

    const input = document.createElement('input');
    input.type = 'text';
    input.value = oldName;
    input.className = 'rename-input';
    input.style.flex = '1';
    input.style.marginBottom = '0';

    const saveBtn = document.createElement('button');
    saveBtn.textContent = 'Save';
    saveBtn.className = 'primary';
    saveBtn.style.padding = '4px 12px';
    saveBtn.style.fontSize = '0.82rem';

    const cancelBtn = document.createElement('button');
    cancelBtn.textContent = 'Cancel';
    cancelBtn.className = 'secondary';
    cancelBtn.style.padding = '4px 12px';
    cancelBtn.style.fontSize = '0.82rem';

    wrapper.appendChild(input);
    wrapper.appendChild(saveBtn);
    wrapper.appendChild(cancelBtn);

    nameDiv.innerHTML = '';
    nameDiv.appendChild(wrapper);
    input.focus();
    input.select();

    async function save() {
        const newName = input.value.trim();
        if (newName && newName !== oldName) {
            await renameGroup(oldName, newName);
        } else {
            renderGroups();
        }
    }

    input.onkeydown = (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            save();
        }
        if (e.key === 'Escape') {
            e.preventDefault();
            renderGroups();
        }
    };

    saveBtn.onclick = (e) => {
        e.stopPropagation();
        save();
    };

    cancelBtn.onclick = (e) => {
        e.stopPropagation();
        renderGroups();
    };
}

function formatDuration(seconds) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    if (h > 0) return h + 'h ' + m + 'm';
    if (m > 0) return m + 'm ' + s + 's';
    return s + 's';
}

function renderClips() {
    const container = document.getElementById('clip-list');
    container.innerHTML = '';

    if (clips.length === 0) {
        container.innerHTML = '<div class="empty-state">No clips here. ' +
            (currentView === 'all' ? 'Extract some clips first.' : 'Add clips to this group from "All Clips".') +
            '</div>';
        return;
    }

    clips.forEach((clip, index) => {
        const div = document.createElement('div');
        div.className = 'clip-item' + (clip.id === selectedClipId ? ' selected' : '');
        div.dataset.index = index;
        div.dataset.id = clip.id;

        const noteText = clip.note ? clip.note : 'No note';
        const noteClass = clip.note ? '' : ' empty';
        const rating = clip.rating || 0;
        const resultBadge = clip.result ?
            '<span class="result-badge ' + clip.result + '">' + clip.result + '</span>' :
            '';
        const ratingHtml = '<div class="rating-row">' +
            '<div class="star-rating-display">' + renderStarsDisplay(rating) + '</div>' + resultBadge +
            '</div>';

        let groupActionHtml = '';
        if (filterMode === 'deleted') {
            groupActionHtml = '<button class="secondary" onclick="event.stopPropagation(); restoreClip(\'' + escapeHtml(clip.id) + '\')">Restore</button>';
        } else if (currentView === 'all') {
            const assignedGroups = clip.groups || [];
            if (assignedGroups.length > 0) {
                const groupName = escapeHtml(assignedGroups[0]);
                groupActionHtml = '<div class="group-badge" onclick="event.stopPropagation(); openGroup(\'' + groupName + '\')">' + groupName + '</div>';
            } else {
                groupActionHtml = '<select onchange="event.stopPropagation(); addToGroup(this, \'' + escapeHtml(clip.id) + '\')">' +
                    '<option value="">Add to group...</option>' +
                    groups.map(g => '<option value="' + escapeHtml(g.name) + '">' + escapeHtml(g.name) + '</option>').join('') +
                    '<option value="__new__">+ New Group...</option>' +
                    '</select>';
            }
        } else {
            groupActionHtml = '<button class="secondary" onclick="event.stopPropagation(); removeFromGroup(\'' + escapeHtml(clip.id) + '\')">Remove</button>';
        }

        const dragHandle = (currentView === 'group-detail' && filterMode !== 'deleted') ?
            '<span class="drag-handle">&#x2630;</span>' :
            '';

        const displayTitle = clip.title ? clip.title : clip.filename;

        div.innerHTML = dragHandle +
            '<div class="info">' +
            '<div class="name">' + escapeHtml(displayTitle) + '</div>' +
            '<div class="note' + noteClass + '">' + escapeHtml(noteText) + '</div>' +
            '</div>' +
            '<div class="actions">' + ratingHtml + groupActionHtml + '</div>';

        if (currentView === 'group-detail' && filterMode !== 'deleted') {
            div.draggable = true;
            div.addEventListener('dragstart', (e) => {
                e.dataTransfer.setData('text/plain', index);
                div.classList.add('dragging');
            });
            div.addEventListener('dragend', () => {
                div.classList.remove('dragging');
            });
            div.addEventListener('dragover', (e) => {
                e.preventDefault();
            });
            div.addEventListener('drop', (e) => {
                e.preventDefault();
                e.stopPropagation();
                const oldIndex = parseInt(e.dataTransfer.getData('text/plain'));
                const newIndex = parseInt(div.dataset.index);
                if (oldIndex !== newIndex && !isNaN(oldIndex) && !isNaN(newIndex)) {
                    reorderClip(oldIndex, newIndex);
                }
            });
        }

        div.addEventListener('click', (e) => {
            if (e.target.tagName === 'SELECT' || e.target.tagName === 'BUTTON') return;
            selectClip(clip.id);
        });

        container.appendChild(div);
    });
}

async function reorderClip(oldIndex, newIndex) {
    const res = await fetch('/api/reorder', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            group: selectedGroup,
            old_index: oldIndex,
            new_index: newIndex
        })
    });
    if (res.ok) {
        await loadClips();
    } else {
        alert('Failed to reorder');
    }
}

async function selectClip(id) {
    selectedClipId = id;
    document.querySelectorAll('.clip-item').forEach(el => {
        el.classList.toggle('selected', el.dataset.id === id);
    });

    const res = await fetch('/api/clip/' + encodeURIComponent(id));
    const clip = await res.json();
    if (clip.error) {
        resetEditor();
        return;
    }

    const displayTitle = clip.title || clip.filename;
    document.getElementById('meta-filename').textContent = escapeHtml(clip.filename);

    const audioTrack = document.getElementById('audio-track').value;
    const videoSrc = '/clip/' + encodeURIComponent(clip.filename) + '?audio_track=' + audioTrack;
    const videoWrapper = document.getElementById('video-wrapper');
    videoWrapper.innerHTML = '<video src="' + videoSrc + '" controls></video>';

    const video = document.querySelector('video');
    if (video) {
        video.addEventListener('loadedmetadata', function() {
            renderCuts(currentCuts);
        });
    }

    const titleInput = document.getElementById('title-input');
    titleInput.value = displayTitle;
    titleInput.disabled = false;
    titleInput.placeholder = clip.filename;

    const noteInput = document.getElementById('note-input');
    noteInput.value = clip.note || '';
    noteInput.disabled = false;

    renderStarsInteractive(clip.rating || 0);
    renderResult(clip.result || '');
    renderCuts(clip.cuts || []);
    document.getElementById('save-status').textContent = '';

    if (clip.deleted) {
        document.getElementById('delete-btn').style.display = 'none';
        document.getElementById('restore-btn').style.display = 'inline-block';
    } else {
        document.getElementById('delete-btn').style.display = 'inline-block';
        document.getElementById('restore-btn').style.display = 'none';
    }
}

async function changeAudioTrack() {
    if (!selectedClipId) return;
    const clip = await fetch('/api/clip/' + encodeURIComponent(selectedClipId)).then(r => r.json());
    if (clip.error) return;

    const audioTrack = document.getElementById('audio-track').value;
    const videoSrc = '/clip/' + encodeURIComponent(clip.filename) + '?audio_track=' + audioTrack;
    const videoWrapper = document.getElementById('video-wrapper');
    videoWrapper.innerHTML = '<video src="' + videoSrc + '" controls></video>';
}

async function openClipFile() {
    if (!selectedClipId) return;
    const res = await fetch('/api/clip/' + encodeURIComponent(selectedClipId) + '/open', {
        method: 'POST'
    });
    const data = await res.json();
    if (!res.ok) {
        alert('Could not open file: ' + (data.error || 'Unknown error'));
    }
}

async function saveNote() {
    if (!selectedClipId) return;
    const note = document.getElementById('note-input').value;
    const res = await fetch('/api/note', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: selectedClipId,
            note: note
        })
    });
    if (res.ok) {
        document.getElementById('save-status').textContent = 'Saved';
        setTimeout(() => {
            document.getElementById('save-status').textContent = '';
        }, 2000);
        await loadClips();
    } else {
        document.getElementById('save-status').textContent = 'Error saving';
    }
}

async function saveTitle() {
    if (!selectedClipId) return;
    const title = document.getElementById('title-input').value;
    const res = await fetch('/api/title', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: selectedClipId,
            title: title
        })
    });
    if (res.ok) {
        document.getElementById('save-status').textContent = 'Title saved';
        setTimeout(() => {
            document.getElementById('save-status').textContent = '';
        }, 2000);
        await loadClips();
    } else {
        document.getElementById('save-status').textContent = 'Error saving title';
    }
}

let currentCutStart = null;
let currentCuts = [];

function markCutStart() {
    const video = document.querySelector('video');
    if (!video) return;
    currentCutStart = video.currentTime;
    document.getElementById('save-status').textContent = 'Cut start: ' + formatTime(currentCutStart);
}

function markCutEnd() {
    if (currentCutStart === null) {
        alert('Press [ Mark Cut first to set a start point');
        return;
    }
    const video = document.querySelector('video');
    if (!video) return;
    const end = video.currentTime;
    if (end <= currentCutStart) {
        alert('End time must be after start time');
        return;
    }
    currentCuts.push({
        start: currentCutStart,
        end: end
    });
    currentCutStart = null;
    renderCuts(currentCuts);
    saveCuts();
}

function clearCuts() {
    if (!confirm('Clear all cuts?')) return;
    currentCuts = [];
    currentCutStart = null;
    renderCuts(currentCuts);
    saveCuts();
}

function deleteCut(index) {
    currentCuts.splice(index, 1);
    renderCuts(currentCuts);
    saveCuts();
}

async function saveCuts() {
    if (!selectedClipId) return;
    const res = await fetch('/api/cuts', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: selectedClipId,
            cuts: currentCuts
        })
    });
    if (res.ok) {
        document.getElementById('save-status').textContent = 'Cuts saved';
        setTimeout(() => {
            document.getElementById('save-status').textContent = '';
        }, 2000);
    } else {
        document.getElementById('save-status').textContent = 'Error saving cuts';
    }
}

function renderCuts(cuts) {
    currentCuts = cuts;
    const controls = document.getElementById('video-controls');
    const timeline = document.getElementById('cut-timeline');
    const list = document.getElementById('cut-list');

    controls.style.display = 'flex';

    const video = document.querySelector('video');
    const duration = video ? video.duration : 0;

    if (duration > 0) {
        timeline.innerHTML = '';
        if (cuts && cuts.length > 0) {
            cuts.forEach(cut => {
                const left = (cut.start / duration) * 100;
                const width = ((cut.end - cut.start) / duration) * 100;
                const div = document.createElement('div');
                div.className = 'cut-segment';
                div.style.left = left + '%';
                div.style.width = width + '%';
                div.title = formatTime(cut.start) + ' - ' + formatTime(cut.end);
                timeline.appendChild(div);
            });
        }
    } else {
        timeline.innerHTML = '<div style="font-size:0.75rem; color:var(--text-muted); padding:2px 6px;">Play video to see timeline</div>';
    }

    list.innerHTML = '';
    if (cuts && cuts.length > 0) {
        cuts.forEach((cut, index) => {
            const item = document.createElement('span');
            item.className = 'cut-item';
            item.innerHTML = 'Cut ' + (index + 1) + ': ' + formatTime(cut.start) + ' - ' + formatTime(cut.end) +
                ' <button onclick="deleteCut(' + index + ')">x</button>';
            list.appendChild(item);
        });
    } else {
        list.innerHTML = '<span style="opacity:0.5">No cuts defined</span>';
    }
}

function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    const ms = Math.floor((seconds % 1) * 100);
    return m + ':' + (s < 10 ? '0' : '') + s + '.' + (ms < 10 ? '0' : '') + ms;
}

async function deleteSelected() {
    if (!selectedClipId) return;
    if (!confirm('Delete this clip? It will be moved to the trash folder.')) return;
    const res = await fetch('/api/clip/' + encodeURIComponent(selectedClipId), {
        method: 'DELETE'
    });
    if (res.ok) {
        selectedClipId = null;
        resetEditor();
        await loadClips();
    }
}

async function restoreSelected() {
    if (!selectedClipId) return;
    const res = await fetch('/api/clip/' + encodeURIComponent(selectedClipId), {
        method: 'DELETE'
    });
    if (res.ok) {
        await loadClips();
        if (selectedClipId) {
            selectClip(selectedClipId);
        }
    }
}

async function restoreClip(id) {
    const res = await fetch('/api/clip/' + encodeURIComponent(id), {
        method: 'DELETE'
    });
    if (res.ok) {
        await loadClips();
    }
}

async function addToGroup(select, clipId) {
    const groupName = select.value;
    select.value = '';
    if (!groupName) return;

    if (groupName === '__new__') {
        const name = prompt('Enter group name:');
        if (!name || !name.trim()) return;
        const createRes = await fetch('/api/groups', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: name.trim()
            })
        });
        if (!createRes.ok) {
            const data = await createRes.json();
            alert(data.error || 'Failed to create group');
            return;
        }
        await loadGroups();
        await loadGroupStats();
        await addClipToGroup(name.trim(), clipId);
    } else {
        await addClipToGroup(groupName, clipId);
    }
}

async function addClipToGroup(groupName, clipId) {
    const res = await fetch('/api/group/' + encodeURIComponent(groupName) + '/add', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            clip_id: clipId
        })
    });
    if (res.ok) {
        await loadClips();
        await loadGroupStats();
    } else {
        alert('Failed to add clip to group');
    }
}

async function removeFromGroup(clipId) {
    const res = await fetch('/api/group/' + encodeURIComponent(selectedGroup) + '/remove', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            clip_id: clipId
        })
    });
    if (res.ok) {
        selectedClipId = null;
        resetEditor();
        await loadClips();
        await loadGroupStats();
    } else {
        alert('Failed to remove clip from group');
    }
}

async function createGroup() {
    const input = document.getElementById('new-group-name');
    const name = input.value.trim();
    if (!name) return;

    const res = await fetch('/api/groups', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            name: name
        })
    });
    if (res.ok) {
        input.value = '';
        cancelNewGroupInline();
        await loadGroups();
        await loadGroupStats();
        if (currentView === 'groups') {
            renderGroups();
        }
    } else {
        const data = await res.json();
        alert(data.error || 'Failed to create group');
    }
}

function showNewGroupFormInline() {
    document.getElementById('new-group-card').style.display = 'none';
    document.getElementById('new-group-inline-form').style.display = 'block';
    document.getElementById('new-group-name').focus();
}

function cancelNewGroupInline() {
    document.getElementById('new-group-card').style.display = 'flex';
    document.getElementById('new-group-inline-form').style.display = 'none';
    document.getElementById('new-group-name').value = '';
}

async function deleteGroup(name) {
    if (!confirm('Delete group "' + name + '"? Clips will not be deleted.')) return;
    await fetch('/api/groups/' + encodeURIComponent(name), {
        method: 'DELETE'
    });
    await loadGroups();
    await loadGroupStats();
    if (currentView === 'groups') {
        renderGroups();
    } else if (currentView === 'group-detail' && selectedGroup === name) {
        switchView('groups');
    }
}

async function renameGroup(oldName, newName) {
    const res = await fetch('/api/groups/rename', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            old_name: oldName,
            new_name: newName
        })
    });
    if (res.ok) {
        if (selectedGroup === oldName) selectedGroup = newName;
        await loadGroups();
        await loadGroupStats();
        if (currentView === 'groups') {
            renderGroups();
        } else if (currentView === 'group-detail') {
            updateTitle();
        }
    } else {
        const data = await res.json();
        alert(data.error || 'Failed to rename group');
        renderGroups();
    }
}

function setFilter(mode) {
    filterMode = mode;
    applyFilter();
}

async function exportGroup() {
    const group = selectedGroup;
    if (!group) {
        alert('No group selected');
        return;
    }
    const filename = document.getElementById('export-filename').value.trim();
    const btn = document.querySelector('#group-export-controls button[onclick="exportGroup()"]');
    const originalText = btn.textContent;
    btn.textContent = 'Exporting...';
    btn.disabled = true;

    const res = await fetch('/api/export', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            group: group,
            output_basename: filename || null
        })
    });

    btn.textContent = originalText;
    btn.disabled = false;

    const data = await res.json();
    if (res.ok) {
        alert('Exported successfully!\n' + data.spliced + '\n' + data.kdenlive);
    } else {
        alert('Export failed: ' + (data.error || 'Unknown error'));
    }
}

function resetEditor() {
    const titleInput = document.getElementById('title-input');
    titleInput.value = 'No clip selected';
    titleInput.disabled = true;
    document.getElementById('meta-filename').textContent = '—';
    document.getElementById('editor-rating').innerHTML = '';
    renderResult('');
    currentCutStart = null;
    currentCuts = [];
    document.getElementById('video-controls').style.display = 'none';
    document.getElementById('cut-timeline').innerHTML = '';
    document.getElementById('cut-list').innerHTML = '';
    document.getElementById('video-wrapper').innerHTML = '<div class="placeholder">Select a clip to preview</div>';
    const noteInput = document.getElementById('note-input');
    noteInput.value = '';
    noteInput.disabled = true;
    document.getElementById('save-status').textContent = '';
    const deleteBtn = document.getElementById('delete-btn');
    const restoreBtn = document.getElementById('restore-btn');
    if (deleteBtn) deleteBtn.style.display = 'none';
    if (restoreBtn) restoreBtn.style.display = 'none';
}

function renderStarsDisplay(rating) {
    let html = '';
    for (let i = 1; i <= 5; i++) {
        html += '<span class="star' + (i <= rating ? ' filled' : '') + '">★</span>';
    }
    return html;
}

function renderStarsInteractive(rating) {
    const container = document.getElementById('editor-rating');
    container.innerHTML = '';
    for (let i = 1; i <= 5; i++) {
        const star = document.createElement('span');
        star.className = 'star' + (i <= rating ? ' filled' : '');
        star.textContent = '★';
        star.dataset.value = i;
        star.onclick = () => setRating(i);
        container.appendChild(star);
    }
}

function renderResult(result) {
    const radios = document.querySelectorAll('input[name="result"]');
    radios.forEach(radio => {
        radio.checked = radio.value === result;
    });
}

async function setResult(result) {
    if (!selectedClipId) return;
    const res = await fetch('/api/result', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: selectedClipId,
            result: result
        })
    });
    if (res.ok) {
        renderResult(result);
        document.getElementById('save-status').textContent = 'Result saved';
        setTimeout(() => {
            document.getElementById('save-status').textContent = '';
        }, 2000);
        await loadClips();
    }
}

async function setRating(rating) {
    if (!selectedClipId) return;
    const res = await fetch('/api/rating', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            id: selectedClipId,
            rating: rating
        })
    });
    if (res.ok) {
        renderStarsInteractive(rating);
        document.getElementById('save-status').textContent = 'Rating saved';
        setTimeout(() => {
            document.getElementById('save-status').textContent = '';
        }, 2000);
        await loadClips();
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}