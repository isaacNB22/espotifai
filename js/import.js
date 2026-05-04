/* ═══════════════════════════════════════════
   import.js — Vista Importar URL
   ═══════════════════════════════════════════ */
'use strict';

let _importedVideo = null;
let _importHist = [];
let _importInited = false;

try {
  _importHist = JSON.parse(localStorage.getItem('yt_h') || '[]');
} catch (_) {}

/* ── Init ── */
function initImportView() {
  const $urlInput = document.getElementById('urlInput');
  const $importBtn = document.getElementById('importBtn');
  const $addBtn = document.getElementById('importAddBtn');
  const $clearBtn = document.getElementById('clearHistBtn');

  if (!$urlInput) return;

  if (!_importInited) {
    _importInited = true;
    $urlInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') handleImport();
    });
    $importBtn?.addEventListener('click', handleImport);
    $addBtn?.addEventListener('click', addImportedToLibrary);
    $clearBtn?.addEventListener('click', clearImportHist);

    // Auto-detect URL in clipboard — only register once
    document.addEventListener('visibilitychange', async () => {
      if (document.visibilityState !== 'visible') return;
      const $input = document.getElementById('urlInput');
      if (!$input) return;
      try {
        const text = await navigator.clipboard.readText();
        if (extractVideoId(text) && text !== $input.value) {
          $input.value = text;
          handleImport();
        }
      } catch (_) {
        /* permission denied */
      }
    });
  }

  renderImportHist();
}

async function handleImport() {
  const val = document.getElementById('urlInput')?.value.trim();
  if (!val) return;

  const id = extractVideoId(val);
  if (!id) {
    setImportError('Enlace no válido. Pega una URL de YouTube completa.');
    return;
  }

  setImportError(null);
  setImportLoading(true);

  try {
    const info = await fetchVideoMeta(id);
    const ytUrl = `https://www.youtube.com/watch?v=${id}`;
    _importedVideo = {
      videoId: id,
      title: info.title,
      author: info.author,
      thumbnail: `https://i.ytimg.com/vi/${id}/mqdefault.jpg`,
      url: ytUrl,
    };

    const thumb = document.getElementById('importThumb');
    if (thumb) thumb.src = _importedVideo.thumbnail;
    const titleEl = document.getElementById('importTitle');
    if (titleEl) titleEl.textContent = info.title;
    const authorEl = document.getElementById('importAuthor');
    if (authorEl) authorEl.textContent = info.author;
    const ytBtn = document.getElementById('importYtBtn');
    if (ytBtn) ytBtn.href = ytUrl;
    const card = document.getElementById('importCard');
    if (card) card.style.display = 'block';

    addImportHist(_importedVideo);
  } catch {
    setImportError('No se pudo cargar la información del video.');
  } finally {
    setImportLoading(false);
  }
}

async function addImportedToLibrary() {
  if (!_importedVideo) return;
  const $btn = document.getElementById('importAddBtn');
  if (!$btn) return;
  $btn.disabled = true;
  $btn.innerHTML = '<span class="spinner"></span>';

  try {
    const res = await apiFetch('/api/library', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(_importedVideo),
    });
    const data = await res.json();

    if (res.ok) {
      showToast(`"${_importedVideo.title}" agregado a la biblioteca`, 'success');
      updateLibCount(1);
      $btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> En biblioteca`;
    } else if (res.status === 409) {
      showToast('Ya está en tu biblioteca', 'info');
      $btn.disabled = false;
      $btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg> Agregar a biblioteca`;
    } else {
      throw new Error(data.error);
    }
  } catch (e) {
    showToast(e.message ?? 'Error al agregar', 'error');
    $btn.disabled = false;
    $btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg> Agregar a biblioteca`;
  }
}

function setImportLoading(on) {
  const $btn = document.getElementById('importBtn');
  if (!$btn) return;
  $btn.disabled = on;
  $btn.innerHTML = on
    ? '<span class="spinner"></span>'
    : `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="6 9 12 15 18 9"/></svg> Cargar`;
}

function setImportError(msg) {
  const $el = document.getElementById('apiImportWarning');
  const $txt = document.getElementById('apiImportWarningText');
  if (!$el) return;
  if (msg) {
    if ($txt) $txt.textContent = msg;
    $el.style.display = 'flex';
  } else $el.style.display = 'none';
}

function addImportHist(item) {
  _importHist = _importHist.filter((h) => h.videoId !== item.videoId);
  _importHist.unshift(item);
  if (_importHist.length > 10) _importHist = _importHist.slice(0, 10);
  try {
    localStorage.setItem('yt_h', JSON.stringify(_importHist));
  } catch (_) {}
  renderImportHist();
}

function clearImportHist() {
  _importHist = [];
  try {
    localStorage.removeItem('yt_h');
  } catch (_) {}
  renderImportHist();
}

function renderImportHist() {
  const $sec = document.getElementById('histSec');
  const $list = document.getElementById('histList');
  if (!$sec || !$list) return;
  if (!_importHist.length) {
    $sec.style.display = 'none';
    return;
  }
  $sec.style.display = 'block';
  $list.innerHTML = _importHist
    .map(
      (h) => `
    <div class="history__item" role="button" tabindex="0"
         onclick="loadImportFromHist(${JSON.stringify(h.url)})"
         onkeydown="if(event.key==='Enter')loadImportFromHist(${JSON.stringify(h.url)})">
      <img class="history__thumb" src="https://i.ytimg.com/vi/${esc(h.videoId)}/default.jpg" alt="" loading="lazy"/>
      <div class="history__info">
        <div class="history__title">${esc(h.title)}</div>
        <div class="history__channel">${esc(h.author)}</div>
      </div>
      <a class="history__dl" href="https://cobalt.tools/#${encodeURIComponent(h.url)}"
         target="_blank" rel="noopener noreferrer" onclick="event.stopPropagation()">Ver</a>
    </div>`
    )
    .join('');
}

function loadImportFromHist(url) {
  const $input = document.getElementById('urlInput');
  if ($input) {
    $input.value = url;
    handleImport();
  }
}

/* ── YouTube metadata helpers ── */
async function fetchVideoMeta(videoId) {
  try {
    const r = await fetch(
      `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`
    );
    if (r.ok) {
      const d = await r.json();
      return { title: d.title, author: d.author_name };
    }
  } catch (_) {}
  return { title: 'Video de YouTube', author: `youtu.be/${videoId}` };
}

function extractVideoId(url) {
  const patterns = [
    /[?&]v=([a-zA-Z0-9_-]{11})/,
    /youtu\.be\/([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/,
    /^([a-zA-Z0-9_-]{11})$/,
  ];
  for (const re of patterns) {
    const m = url.match(re);
    if (m) return m[1];
  }
  return null;
}

/* ── register with nav system ── */
document.addEventListener('view:import', () => initImportView());
