/**
 * GET /api/search?q=query&maxResults=12&duration=short|medium|long&publishedAfter=2020-01-01
 * Busca videos en YouTube usando la Data API v3
 * GET /api/search/suggestions?q=query
 * Sugerencias de autocompletado (sin quota — API pública de Google)
 */

import { Router } from 'express';
import { recordSearch, getQuotaStatus } from '../quota.js';

const router = Router();

// GET /api/search/quota
router.get('/quota', (_req, res) => res.json(getQuotaStatus()));

// GET /api/search/suggestions?q=...  (sin API key, sin quota)
router.get('/suggestions', async (req, res) => {
  const { q } = req.query;
  if (!q?.trim()) return res.json([]);
  try {
    const url = new URL('https://suggestqueries.google.com/complete/search');
    url.searchParams.set('client', 'youtube');
    url.searchParams.set('ds', 'yt');
    url.searchParams.set('q', q.trim());
    url.searchParams.set('hl', 'es');
    // Forzar JSON (callback=yt vacío devuelve JSONP — parseamos el array interno)
    url.searchParams.set('callback', 'yt');
    const resp = await fetch(url.toString());
    const text = await resp.text();
    // Respuesta: yt(["query", [["sug1",0],["sug2",0],...]])
    const match = text.match(/^yt\((.*)\)$/s);
    if (!match) return res.json([]);
    const parsed = JSON.parse(match[1]);
    const suggestions = (parsed[1] ?? []).map((s) => s[0]).slice(0, 8);
    res.json(suggestions);
  } catch {
    res.json([]);
  }
});

router.get('/', async (req, res) => {
  const { q, maxResults = '12', duration, publishedAfter } = req.query;

  if (!q?.trim()) {
    return res.status(400).json({ error: 'El parámetro q es requerido' });
  }

  const key = process.env.YOUTUBE_API_KEY;
  if (!key || key === 'AQUI_VA_TU_API_KEY') {
    return res.status(500).json({ error: 'YOUTUBE_API_KEY no configurada en .env' });
  }

  try {
    const url = new URL('https://www.googleapis.com/youtube/v3/search');
    url.searchParams.set('part', 'snippet');
    url.searchParams.set('q', q.trim());
    url.searchParams.set('maxResults', String(Math.min(Number(maxResults), 25)));
    url.searchParams.set('type', 'video');
    url.searchParams.set('videoCategoryId', '10'); // Música
    url.searchParams.set('key', key);
    // Filtros opcionales (no cuestan unidades extra — mismo request)
    if (duration && ['short', 'medium', 'long'].includes(duration)) {
      url.searchParams.set('videoDuration', duration);
    }
    if (publishedAfter) {
      // Espera ISO 8601: "2020-01-01" → "2020-01-01T00:00:00Z"
      const d = new Date(publishedAfter);
      if (!isNaN(d.getTime())) url.searchParams.set('publishedAfter', d.toISOString());
    }

    const resp = await fetch(url.toString());
    if (!resp.ok) {
      const errData = await resp.json().catch(() => ({}));
      return res
        .status(resp.status)
        .json({ error: errData.error?.message ?? 'Error de YouTube API' });
    }

    const data = await resp.json();
    const results = (data.items ?? []).map((item) => ({
      videoId: item.id.videoId,
      title: item.snippet.title,
      author: item.snippet.channelTitle,
      thumbnail: item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.default?.url ?? '',
      publishedAt: item.snippet.publishedAt,
      description: item.snippet.description,
    }));

    const quota = recordSearch();
    res.json({ results, quota });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
