/* app.js - Core: navigation, theme, profile, utilities */
'use strict';

const API_BASE = window.location.protocol === 'file:' ? 'http://localhost:3000' : '';

function apiFetch(path, opts) {
  return fetch(API_BASE + path, opts || {});
}

function showToast(msg, type, duration) {
  type = type || 'info';
  duration = duration || 3500;
  const c = document.getElementById('toastContainer');
  if (!c) return;
  const icons = {
    success:
      '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>',
    error:
      '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
    info: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>',
  };
  const t = document.createElement('div');
  t.className = 'toast toast--' + type;
  t.innerHTML =
    '<span class="toast__icon">' +
    (icons[type] || icons.info) +
    '</span><span>' +
    esc(msg) +
    '</span>';
  c.appendChild(t);
  setTimeout(() => {
    t.classList.add('out');
    t.addEventListener('animationend', () => t.remove(), { once: true });
  }, duration);
}

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function updateLibCount(delta) {
  const el = document.getElementById('libCount');
  if (!el) return;
  el.textContent = String(Math.max(0, (parseInt(el.textContent, 10) || 0) + delta));
}

const VIEWS = ['search', 'library', 'import', 'stats'];
const VIEW_TITLES = {
  search: 'Buscar',
  library: 'Mi Biblioteca',
  import: 'Importar URL',
  stats: 'Estadisticas',
};
const _viewLoaded = {};

async function _loadViewHTML(viewId) {
  if (_viewLoaded[viewId]) return;
  try {
    const res = await fetch('views/' + viewId + '/' + viewId + '.html');
    if (!res.ok) return;
    const html = await res.text();
    const container = document.getElementById('view-' + viewId);
    if (container) container.innerHTML = html;
    _viewLoaded[viewId] = true;
  } catch (_) {}
}

async function _doNavigation(viewId) {
  await _loadViewHTML(viewId);
  document
    .querySelectorAll('[data-nav]')
    .forEach((el) => el.classList.toggle('active', el.dataset.nav === viewId));
  VIEWS.forEach((v) => {
    const el = document.getElementById('view-' + v);
    if (el) el.classList.toggle('hidden', v !== viewId);
  });
  const titleEl = document.getElementById('topbarTitle');
  if (titleEl) titleEl.textContent = VIEW_TITLES[viewId] || viewId;
  document.dispatchEvent(new CustomEvent('view:' + viewId));
  if (viewId === 'library' && typeof initLibrary === 'function') initLibrary();
  if (viewId === 'stats') loadStats();
  if (viewId === 'import' && typeof initImportView === 'function') initImportView();
}

async function navigateTo(viewId) {
  if (!VIEWS.includes(viewId)) return;
  if (document.startViewTransition) {
    await document.startViewTransition(() => _doNavigation(viewId)).ready;
  } else {
    await _doNavigation(viewId);
  }
}

async function checkApiStatus() {
  const dot = document.getElementById('apiStatus');
  const warn = document.getElementById('apiWarning');
  const warnText = document.getElementById('apiWarningText');
  try {
    const res = await apiFetch('/api/ping');
    if (res.ok) {
      dot?.classList.remove('offline');
      dot?.classList.add('online');
      if (warn) warn.style.display = 'none';
    } else throw new Error();
  } catch {
    dot?.classList.remove('online');
    dot?.classList.add('offline');
    if (warn && warnText) {
      warnText.textContent = 'Servidor no disponible. Inicia con: cd server && npm run dev';
      warn.style.display = 'flex';
    }
  }
}

async function loadStats() {
  try {
    const [qRes, lRes] = await Promise.all([
      apiFetch('/api/search/quota'),
      apiFetch('/api/library'),
    ]);
    if (qRes.ok) {
      const q = await qRes.json();
      const pct = Math.min(100, Math.round((q.used / q.limit) * 100));
      const bar = document.getElementById('statsQuotaBar');
      if (bar) {
        bar.style.width = pct + '%';
        bar.className = 'quota-bar-fill' + (pct >= 90 ? ' crit' : pct >= 70 ? ' warn' : '');
      }
      const s = (id, val) => {
        const e = document.getElementById(id);
        if (e) e.textContent = val;
      };
      s('statsUsed', q.used.toLocaleString());
      s('statsRemaining', q.remaining.toLocaleString());
      s('statsPercent', pct + '%');
      s('statsSearches', Math.floor(q.remaining / 100).toLocaleString());
      s('statsReset', q.resetDate ? 'Reinicia: ' + q.resetDate : '');
    }
    if (lRes.ok) {
      const tracks = await lRes.json();
      const s = (id, val) => {
        const e = document.getElementById(id);
        if (e) e.textContent = val;
      };
      s('statsTracks', tracks.length);
      s('statsDownloaded', tracks.filter((t) => t.downloadStatus === 'done').length);
    }
  } catch (_) {}
}

document.addEventListener('DOMContentLoaded', () => {
  const html = document.documentElement;
  const themeBtn = document.getElementById('themeToggle');
  const iconSun = document.getElementById('iconSun');
  const iconMoon = document.getElementById('iconMoon');

  function applyTheme(theme) {
    if (theme === 'light') {
      html.classList.add('light');
      if (iconSun) iconSun.style.display = 'none';
      if (iconMoon) iconMoon.style.display = '';
    } else {
      html.classList.remove('light');
      if (iconSun) iconSun.style.display = '';
      if (iconMoon) iconMoon.style.display = 'none';
    }
  }
  applyTheme(localStorage.getItem('esp_theme') || 'dark');
  themeBtn?.addEventListener('click', () => {
    const next = html.classList.contains('light') ? 'dark' : 'light';
    localStorage.setItem('esp_theme', next);
    applyTheme(next);
  });

  const avatarBtn = document.getElementById('avatarBtn');
  const profilePanel = document.getElementById('profilePanel');
  const profileBackdrop = document.getElementById('profileBackdrop');
  const profileClose = document.getElementById('profileClose');
  function openProfile() {
    profilePanel?.classList.add('open');
    profileBackdrop?.classList.add('open');
    loadQuota();
  }
  function closeProfile() {
    profilePanel?.classList.remove('open');
    profileBackdrop?.classList.remove('open');
  }
  avatarBtn?.addEventListener('click', openProfile);
  profileClose?.addEventListener('click', closeProfile);
  profileBackdrop?.addEventListener('click', closeProfile);

  async function loadQuota() {
    try {
      const res = await apiFetch('/api/search/quota');
      if (!res.ok) return;
      const q = await res.json();
      const pct = Math.min(100, Math.round((q.used / q.limit) * 100));
      const fill = document.getElementById('quotaBarFill');
      if (fill) {
        fill.style.width = pct + '%';
        fill.className = 'quota-bar-fill' + (pct >= 90 ? ' crit' : pct >= 70 ? ' warn' : '');
      }
      const s = (id, val) => {
        const e = document.getElementById(id);
        if (e) e.textContent = val;
      };
      s('quotaUsed', q.used.toLocaleString());
      s('quotaRemaining', q.remaining.toLocaleString());
      s('quotaPercent', pct + '%');
      s('quotaSearches', Math.floor(q.remaining / 100).toLocaleString());
      const reset = document.getElementById('quotaReset');
      if (reset && q.resetDate) reset.textContent = 'Reinicia: ' + q.resetDate;
    } catch (_) {}
  }

  document.querySelectorAll('[data-nav]').forEach((el) => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      navigateTo(el.dataset.nav);
    });
  });

  apiFetch('/api/library')
    .then((r) => r.json())
    .then((tracks) => {
      const c = document.getElementById('libCount');
      if (c && Array.isArray(tracks)) c.textContent = tracks.length || '0';
      if (typeof syncLibrarySet === 'function') syncLibrarySet(tracks);
      if (window.espotifaiPlayer) window.espotifaiPlayer.load(tracks);
    })
    .catch(() => {});

  // Load initial view (search) without transition
  _loadViewHTML('search').then(() => {
    document.dispatchEvent(new CustomEvent('view:search'));
  });

  checkApiStatus();
  setInterval(checkApiStatus, 30000);

  // Service Worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }
});
