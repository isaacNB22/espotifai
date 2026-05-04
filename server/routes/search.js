/**
 * GET /api/search?q=query&maxResults=12
 * Busca videos en YouTube usando la Data API v3
 */

import { Router } from 'express';
import { recordSearch, getQuotaStatus } from '../quota.js';

const router = Router();

// GET /api/search/quota
router.get('/quota', (_req, res) => res.json(getQuotaStatus()));

router.get('/', async (req, res) => {
  const { q, maxResults = '12' } = req.query;

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
