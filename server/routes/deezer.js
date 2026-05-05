/**
 * Rutas Deezer — API pública, sin API key
 *
 * GET /api/deezer/trending-artists     → artistas trending del chart de Deezer
 * GET /api/deezer/genres               → géneros musicales con imagen
 * GET /api/deezer/artist/:id           → detalle completo de artista
 * GET /api/deezer/search-artist?q=     → buscar artista por nombre → devuelve id
 */

import { Router } from 'express';

const router = Router();
const BASE = 'https://api.deezer.com';

async function deezerGet(path) {
  const res = await fetch(`${BASE}${path}`);
  if (!res.ok) throw new Error(`Deezer ${res.status}`);
  return res.json();
}

// GET /api/deezer/trending-artists
router.get('/trending-artists', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit ?? '12', 10);
    const data = await deezerGet('/chart/0/artists?limit=' + limit);
    const artists = (data.data ?? []).map((a) => ({
      id: a.id,
      name: a.name,
      thumbnail: a.picture_xl ?? a.picture_big ?? a.picture ?? '',
      tracklist: a.tracklist ?? '',
      link: a.link ?? '',
      position: a.position ?? 0,
    }));
    res.json(artists);
  } catch (e) {
    res.status(502).json({ error: e.message });
  }
});

// GET /api/deezer/genres
router.get('/genres', async (req, res) => {
  try {
    const data = await deezerGet('/genre');
    const genres = (data.data ?? [])
      .filter((g) => g.id !== 0)
      .map((g) => ({
        id: g.id,
        name: g.name,
        thumbnail: g.picture_xl ?? g.picture_big ?? g.picture ?? '',
      }));
    res.json(genres);
  } catch (e) {
    res.status(502).json({ error: e.message });
  }
});

// GET /api/deezer/search-artist?q=nombre
// Devuelve el primer resultado de búsqueda de artista (id + info básica)
router.get('/search-artist', async (req, res) => {
  try {
    const q = req.query.q ?? '';
    if (!q) return res.status(400).json({ error: 'q requerido' });
    const data = await deezerGet(`/search/artist?q=${encodeURIComponent(q)}&limit=1`);
    const a = (data.data ?? [])[0];
    if (!a) return res.status(404).json({ error: 'No encontrado' });
    res.json({
      id: a.id,
      name: a.name,
      thumbnail: a.picture_xl ?? a.picture_big ?? a.picture ?? '',
      nb_fan: a.nb_fan ?? 0,
      nb_album: a.nb_album ?? 0,
    });
  } catch (e) {
    res.status(502).json({ error: e.message });
  }
});

// GET /api/deezer/artist/:id
// Devuelve info completa: datos del artista, top tracks, álbumes y artistas relacionados
router.get('/artist/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const [info, topData, albumData, relatedData] = await Promise.all([
      deezerGet(`/artist/${id}`),
      deezerGet(`/artist/${id}/top?limit=10`),
      deezerGet(`/artist/${id}/albums?limit=10`),
      deezerGet(`/artist/${id}/related?limit=8`),
    ]);

    const topTracks = (topData.data ?? []).map((t) => ({
      id: t.id,
      title: t.title,
      artist: info.name,
      thumbnail: t.album?.cover_xl ?? t.album?.cover_big ?? t.album?.cover ?? '',
      albumName: t.album?.title ?? '',
      duration: t.duration ?? 0,
      rank: t.rank ?? 0,
      preview: t.preview ?? '',
    }));

    const albums = (albumData.data ?? []).map((a) => ({
      id: a.id,
      title: a.title,
      cover: a.cover_xl ?? a.cover_big ?? a.cover ?? '',
      releaseDate: a.release_date ?? '',
      nbTracks: a.nb_tracks ?? 0,
      recordType: a.record_type ?? 'album',
      fans: a.fans ?? 0,
    }));

    const related = (relatedData.data ?? []).map((a) => ({
      id: a.id,
      name: a.name,
      thumbnail: a.picture_xl ?? a.picture_big ?? a.picture ?? '',
      nb_fan: a.nb_fan ?? 0,
    }));

    res.json({
      id: info.id,
      name: info.name,
      thumbnail: info.picture_xl ?? info.picture_big ?? info.picture ?? '',
      nb_fan: info.nb_fan ?? 0,
      nb_album: info.nb_album ?? 0,
      radio: info.radio ?? false,
      link: info.link ?? '',
      topTracks,
      albums,
      related,
    });
  } catch (e) {
    res.status(502).json({ error: e.message });
  }
});
export default router;
