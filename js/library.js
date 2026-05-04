/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   espotifai â€” Library View
   Maneja la biblioteca de tracks y las descargas
   â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

'use strict';

const _activeJobs = new Map();
let _pollInterval = null;
let _libInited = false;
let _allTracks = [];
let _sortKey = null;
let _sortDir = 1; // 1=asc, -1=desc

function initLibrary() {
  if (_libInited) {
    loadLibrary(); // already wired, just refresh
    return;
  }
  _libInited = true;
  const refreshBtn = document.getElementById('refreshLibBtn');
  if (refreshBtn) refreshBtn.addEventListener('click', loadLibrary);

  // Búsqueda en biblioteca (delegada: el input puede no existir aún)
  document.addEventListener('input', (e) => {
    if (e.target?.id === 'libSearch') _applyFilters();
  });

  // Ordenar por columna
  document.addEventListener('click', (e) => {
    const col = e.target?.closest?.('.lib-sort-col');
    if (!col) return;
    const key = col.dataset.sort;
    if (_sortKey === key) _sortDir *= -1;
    else {
      _sortKey = key;
      _sortDir = 1;
    }
    _applyFilters();
    // Update arrows
    document.querySelectorAll('.lib-sort-col .sort-arrow').forEach((a) => (a.textContent = ''));
    const arrow = col.querySelector('.sort-arrow');
    if (arrow) arrow.textContent = _sortDir === 1 ? ' ▲' : ' ▼';
  });

  loadLibrary();
}

async function loadLibrary() {
  const $list = document.getElementById('libraryList');
  if (!$list) return;
  const $err = document.getElementById('libErr');

  setLibError(null);
  $list.innerHTML = '<div class="results-empty"><span class="spinner"></span></div>';

  try {
    const res = await apiFetch('/api/library');
    const tracks = await res.json();

    if (!res.ok) {
      setLibError(tracks.error ?? 'Error al cargar la biblioteca');
      $list.innerHTML = libEmptyState();
      return;
    }

    // Sincronizar set de bÃºsqueda
    if (typeof syncLibrarySet === 'function') syncLibrarySet(tracks);

    // Actualizar badge
    const countEl = document.getElementById('libCount');
    if (countEl) countEl.textContent = tracks.length || '0';

    if (!tracks.length) {
      $list.innerHTML = libEmptyState();
      return;
    }

    _allTracks = tracks;
    _applyFilters();
    startPolling(tracks);
  } catch {
    setLibError('No se pudo conectar al servidor. Â¿EstÃ¡ corriendo?');
    $list.innerHTML = libEmptyState();
  }
}

function _applyFilters() {
  const $list = document.getElementById('libraryList');
  if (!$list) return;
  const q = (document.getElementById('libSearch')?.value ?? '').toLowerCase().trim();
  let tracks = _allTracks.filter(
    (t) => !q || t.title?.toLowerCase().includes(q) || t.author?.toLowerCase().includes(q)
  );
  if (_sortKey) {
    tracks = tracks.slice().sort((a, b) => {
      let va = _sortKey === 'duration' ? (a.duration ?? 0) : (a.title ?? '').toLowerCase();
      let vb = _sortKey === 'duration' ? (b.duration ?? 0) : (b.title ?? '').toLowerCase();
      return va < vb ? -_sortDir : va > vb ? _sortDir : 0;
    });
  }
  if (!tracks.length) {
    $list.innerHTML = libEmptyState();
    return;
  }
  renderLibrary($list, tracks);
}

function renderLibrary($list, tracks) {
  // AutoAnimate — anima entradas/salidas de filas automáticamente
  if (window.autoAnimate) window.autoAnimate($list);

  $list.innerHTML = tracks.map((t, i) => buildTrackRow(t, i + 1)).join('');

  // Tippy tooltips en botones de acción
  if (window.tippy) {
    tippy($list.querySelectorAll('[data-tippy-content]'), {
      theme: 'esp',
      placement: 'top',
      arrow: false,
      duration: [100, 80],
      offset: [0, 6],
    });
  }

  // Update player playlist
  if (window.espotifaiPlayer) window.espotifaiPlayer.load(tracks);

  // Eventos
  $list.querySelectorAll('[data-action="download"]').forEach(($btn) => {
    $btn.addEventListener('click', () => startDownload($btn.dataset.videoId));
  });
  $list.querySelectorAll('[data-action="save"]').forEach(($btn) => {
    $btn.addEventListener('click', () => saveFile($btn.dataset.videoId));
  });
  $list.querySelectorAll('[data-action="remove"]').forEach(($btn) => {
    $btn.addEventListener('click', () => removeTrack($btn.dataset.videoId));
  });
  // Todas las pistas son reproducibles (stream local o proxy YouTube)
  $list.querySelectorAll('.lib-track').forEach(($row) => {
    $row.style.cursor = 'pointer';
    $row.addEventListener('click', (e) => {
      if (e.target.closest('button, a')) return;
      window.espotifaiPlayer?.play($row.dataset.videoId);
    });
  });
}

function buildTrackRow(t, num) {
  const canDownload = t.downloadStatus === 'pending' || t.downloadStatus === 'error';
  const canPlay = t.downloadStatus === 'done';
  const dur = t.duration ? fmtDur(t.duration) : '';
  const thumb = t.thumbnail || 'https://i.ytimg.com/vi/' + t.videoId + '/default.jpg';
  const downloadBtn = canDownload
    ? '<button class="btn--icon" data-tippy-content="Descargar MP3" data-action="download" data-video-id="' +
      esc(t.videoId) +
      '"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg></button>'
    : '';
  const saveBtn = canPlay
    ? '<button class="btn--icon" data-tippy-content="Guardar archivo" data-action="save" data-video-id="' +
      esc(t.videoId) +
      '"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg></button>'
    : '';
  const removeBtn =
    '<button class="btn--icon danger" data-tippy-content="Eliminar de biblioteca" data-action="remove" data-video-id="' +
    esc(t.videoId) +
    '"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/></svg></button>';

  return (
    '<div class="lib-track" id="track-' +
    esc(t.videoId) +
    '" data-video-id="' +
    esc(t.videoId) +
    '">' +
    '<span class="lib-track__num">' +
    num +
    '</span>' +
    '<img class="lib-track__thumb" src="' +
    esc(thumb) +
    '" alt="" loading="lazy" />' +
    '<div class="lib-track__info"><div class="lib-track__title">' +
    esc(t.title) +
    '</div><div class="lib-track__author">' +
    esc(t.author) +
    '</div></div>' +
    '<span class="lib-track__duration">' +
    (canPlay && dur ? dur : buildStatus(t)) +
    '</span>' +
    '<div class="lib-track__actions">' +
    downloadBtn +
    saveBtn +
    removeBtn +
    '</div>' +
    '</div>'
  );
}

function fmtDur(s) {
  if (!s || !isFinite(s)) return '';
  const m = Math.floor(s / 60);
  const sec = String(Math.floor(s % 60)).padStart(2, '0');
  return m + ':' + sec;
}

function buildStatus(t) {
  switch (t.downloadStatus) {
    case 'pending':
      return '<span class="status-badge status-badge--pending">Pendiente</span>';
    case 'downloading':
      return (
        '<span class="status-badge status-badge--downloading">Descargando <span class="progress-bar"><span class="progress-bar__fill" style="width:0%" id="progress-' +
        esc(t.videoId) +
        '"></span></span></span>'
      );
    case 'done':
      return '<span class="status-badge status-badge--done"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10" fill="hsl(141,73%,42%)" stroke="none"/><polyline points="8 12 11 15 16 9" stroke="#fff" stroke-width="2.5" fill="none"/></svg></span>';
    case 'error':
      return '<span class="status-badge status-badge--error">Error</span>';
    default:
      return '';
  }
}

// â”€â”€ Download â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// -- Download --

async function startDownload(videoId, format) {
  format = format || 'mp3';
  updateTrackStatus(videoId, 'downloading');
  try {
    const res = await apiFetch('/api/download', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ videoId, format }),
    });
    const data = await res.json();
    if (!res.ok) {
      updateTrackStatus(videoId, 'error');
      showToast(data.error || 'Error al iniciar descarga', 'error');
      return;
    }
    showToast('Descarga iniciada…', 'info');
    _watchJobSSE(data.jobId, videoId);
  } catch {
    updateTrackStatus(videoId, 'error');
    showToast('Sin conexion al servidor', 'error');
  }
}

function _watchJobSSE(jobId, videoId) {
  const API = window.location.protocol === 'file:' ? 'http://localhost:3000' : '';
  const es = new EventSource(API + '/api/download/progress/' + jobId);
  es.onmessage = function (e) {
    const data = JSON.parse(e.data);
    const bar = document.getElementById('progress-' + videoId);
    if (bar) bar.style.width = (data.progress || 0) + '%';
    if (data.status === 'done') {
      es.close();
      updateTrackStatus(videoId, 'done');
      showToast('Descarga completada', 'success');
      apiFetch('/api/library')
        .then(function (r) {
          return r.json();
        })
        .then(function (tracks) {
          if (window.espotifaiPlayer) window.espotifaiPlayer.load(tracks);
        })
        .catch(function () {});
    } else if (data.status === 'error') {
      es.close();
      updateTrackStatus(videoId, 'error');
      showToast('Error: ' + (data.error || 'desconocido'), 'error');
    }
  };
  es.onerror = function () {
    es.close();
  };
}

function updateTrackStatus(videoId, status) {
  const $row = document.getElementById(`track-${videoId}`);
  if (!$row) return;
  // Re-renderizar la fila con el nuevo status
  const title = $row.querySelector('.lib-track__title')?.textContent ?? '';
  const author = $row.querySelector('.lib-track__author')?.textContent ?? '';
  const thumbSrc = $row.querySelector('.lib-track__thumb')?.src ?? '';
  const numText = $row.querySelector('.lib-track__num')?.textContent ?? '';

  const fakeTrack = { videoId, title, author, thumbnail: thumbSrc, downloadStatus: status };
  $row.outerHTML = buildTrackRow(fakeTrack, numText);

  // Reconectar eventos en la nueva fila
  const $newRow = document.getElementById(`track-${videoId}`);
  $newRow
    ?.querySelector('[data-action="download"]')
    ?.addEventListener('click', () => startDownload(videoId));
  $newRow
    ?.querySelector('[data-action="save"]')
    ?.addEventListener('click', () => saveFile(videoId));
  $newRow
    ?.querySelector('[data-action="remove"]')
    ?.addEventListener('click', () => removeTrack(videoId));
}

// â”€â”€ Save / Download file â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function saveFile(videoId) {
  window.open(`${getApiBase()}/api/download/file/${videoId}`, '_blank');
}

// â”€â”€ Remove â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

async function removeTrack(videoId) {
  try {
    const res = await apiFetch(`/api/library/${videoId}`, { method: 'DELETE' });
    if (res.ok) {
      document.getElementById(`track-${videoId}`)?.remove();
      updateLibCount(-1);
      showToast('Eliminado de la biblioteca', 'info');

      const $list = document.getElementById('libraryList');
      if ($list && !$list.querySelector('.lib-track')) {
        $list.innerHTML = libEmptyState();
      }
    } else {
      showToast('No se pudo eliminar', 'error');
    }
  } catch {
    showToast('Sin conexiÃ³n al servidor', 'error');
  }
}

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function setLibError(msg) {
  const $err = document.getElementById('libErr');
  if (!$err) return;
  $err.textContent = msg ?? '';
  $err.style.display = msg ? 'block' : 'none';
}

function libEmptyState() {
  return `
    <div class="lib-empty">
      <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2">
        <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
      </svg>
      <p>Tu biblioteca estÃ¡ vacÃ­a.<br/>Busca canciones y agrÃ©galas.</p>
    </div>`;
}

document.addEventListener('DOMContentLoaded', () => {
  // Se inicializa solo cuando se activa la vista (ver app.js)
  document.addEventListener('view:library', initLibrary, { once: false });
});
