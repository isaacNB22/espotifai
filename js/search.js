/* ─────────────────────────────────────────────
   espotifai — Search View
   Maneja la búsqueda en YouTube y el grid de resultados
   ───────────────────────────────────────────── */

'use strict';

// Set de videoIds ya en biblioteca (sincronizado en cada carga)
const _inLibrary = new Set();

function _initSearchHandlers() {
  const $query = document.getElementById('searchQuery');
  const $btn = document.getElementById('searchBtn');
  const $results = document.getElementById('searchResults');
  const $err = document.getElementById('apiWarning');

  function debounce(fn, ms) {
    let t;
    return (...args) => {
      clearTimeout(t);
      t = setTimeout(() => fn(...args), ms);
    };
  }

  $btn?.addEventListener('click', () => doSearch($query.value));
  $query?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') doSearch($query.value);
  });
  // Búsqueda automática al escribir (con debounce 600ms para no quemar cuota)
  $query?.addEventListener(
    'input',
    debounce(() => {
      if ($query.value.trim().length >= 3) doSearch($query.value);
    }, 600)
  );

  async function doSearch(raw) {
    const q = raw?.trim();
    if (!q) return;

    setSearchError(null);
    showSkeletons($results);
    $btn.disabled = true;

    try {
      const res = await apiFetch(`/api/search?q=${encodeURIComponent(q)}&maxResults=16`);
      const data = await res.json();

      if (!res.ok) {
        setSearchError(data.error ?? 'Error al buscar');
        $results.innerHTML = emptyState('No se pudo obtener resultados');
        return;
      }

      renderResults($results, data.results ?? []);
    } catch (err) {
      setSearchError('No se pudo conectar al servidor. ¿Está corriendo?');
      $results.innerHTML = emptyState('Sin conexión al servidor');
    } finally {
      $btn.disabled = false;
    }
  }

  function setSearchError(msg) {
    if (!$err) return;
    const txt = $err.querySelector('#apiWarningText') || $err;
    txt.textContent = msg ?? '';
    $err.style.display = msg ? 'flex' : 'none';
  }
}

function showSkeletons($container, count = 12) {
  $container.innerHTML = Array.from({ length: count })
    .map(
      () => `
    <div class="skeleton-card">
      <div class="skeleton skeleton-thumb"></div>
      <div class="skeleton-body">
        <div class="skeleton skeleton-line"></div>
        <div class="skeleton skeleton-line skeleton-line--short"></div>
      </div>
    </div>
  `
    )
    .join('');
}

function renderResults($container, results) {
  // AutoAnimate — anima las tarjetas al aparecer
  if (window.autoAnimate) window.autoAnimate($container);

  if (!results.length) {
    $container.innerHTML = emptyState('Sin resultados para esa búsqueda');
    return;
  }

  $container.innerHTML = results
    .map(
      (v) => `
    <div class="result-card" data-video-id="${esc(v.videoId)}">
      <div class="result-card__thumb">
        <img src="${esc(v.thumbnail)}" alt="" loading="lazy" />
        <div class="result-card__overlay">
          <div class="play-icon">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="white"><polygon points="5 3 19 12 5 21 5 3"/></svg>
          </div>
        </div>
      </div>
      <div class="result-card__body">
        <p class="result-card__title">${esc(v.title)}</p>
        <p class="result-card__author">${esc(v.author)}</p>
        <div class="result-card__actions">
          <button
            class="btn--add ${_inLibrary.has(v.videoId) ? 'added' : ''}"
            data-video-id="${esc(v.videoId)}"
            data-title="${esc(v.title)}"
            data-author="${esc(v.author)}"
            data-thumbnail="${esc(v.thumbnail)}"
            ${_inLibrary.has(v.videoId) ? 'disabled' : ''}
          >
            ${
              _inLibrary.has(v.videoId)
                ? `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg> En biblioteca`
                : `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg> Agregar`
            }
          </button>
        </div>
      </div>
    </div>
  `
    )
    .join('');

  // Delegar click en todos los botones de agregar
  $container.querySelectorAll('.btn--add:not(.added)').forEach(($btn) => {
    $btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const { videoId, title, author, thumbnail } = $btn.dataset;
      await addToLibraryFromSearch($btn, { videoId, title, author, thumbnail });
    });
  });
}

async function addToLibraryFromSearch($btn, { videoId, title, author, thumbnail }) {
  $btn.disabled = true;
  $btn.innerHTML = '<span class="spinner"></span>';

  try {
    const res = await apiFetch('/api/library', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ videoId, title, author, thumbnail }),
    });
    const data = await res.json();

    if (res.ok || res.status === 409) {
      _inLibrary.add(videoId);
      $btn.classList.add('added');
      $btn.innerHTML = `
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <polyline points="20 6 9 17 4 12"/>
        </svg> En biblioteca`;
      showToast(
        res.status === 409 ? 'Ya estaba en tu biblioteca' : `"${title}" agregado`,
        'success'
      );

      // Actualizar contador
      updateLibCount(1);
    } else {
      $btn.disabled = false;
      $btn.innerHTML = `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg> Agregar`;
      showToast(data.error ?? 'Error al agregar', 'error');
    }
  } catch {
    $btn.disabled = false;
    $btn.innerHTML = `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg> Agregar`;
    showToast('Sin conexión al servidor', 'error');
  }
}

function emptyState(msg) {
  return `
    <div class="results-empty">
      <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3">
        <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
      </svg>
      <p>${esc(msg)}</p>
    </div>`;
}

// Llamado desde app.js cuando se carga la biblioteca
function syncLibrarySet(tracks) {
  _inLibrary.clear();
  tracks.forEach((t) => _inLibrary.add(t.videoId));
}

// Se inicializa cuando la vista search está en el DOM
let _searchInited = false;
function initSearch() {
  if (_searchInited) return;
  const $query = document.getElementById('searchQuery');
  if (!$query) return;
  _searchInited = true;
  _initSearchHandlers();
}

document.addEventListener('view:search', initSearch);
