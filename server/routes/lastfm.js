/**
 * Rutas Last.fm — sin OAuth, solo API Key
 *
 * GET /api/lastfm/chart/tracks           → canciones tendencia global
 * GET /api/lastfm/chart/artists          → artistas tendencia global
 * GET /api/lastfm/artist/top?artist=...  → top tracks de un artista
 * GET /api/lastfm/similar?track=&artist= → canciones similares
 * GET /api/lastfm/new-releases           → nuevos lanzamientos vía artistas top
 * GET /api/lastfm/search?q=...           → búsqueda de tracks (sin quota YouTube)
 * GET /api/lastfm/resolve?track=&artist= → resuelve videoId de YouTube (lazy, 100 unidades)
 */

import { Router } from 'express';
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);
const router = Router();
const BASE = 'https://ws.audioscrobbler.com/2.0/';

function lfm(key) {
  return (method, params = {}) => {
    const url = new URL(BASE);
    url.searchParams.set('method', method);
    url.searchParams.set('api_key', key);
    url.searchParams.set('format', 'json');
    url.searchParams.set('limit', params.limit ?? 12);
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
    return fetch(url.toString()).then((r) => r.json());
  };
}

/**
 * Busca en YouTube el audio de "artist - track".
 * Intenta primero yt-dlp (gratis, sin quota), luego YouTube Data API como fallback.
 */
const BLOCKED_TITLE = /official\s*(?:music\s*)?video|video\s*(?:musical\s*)?oficial/i;

async function findYouTubeAudio(artist, track, ytKey) {
  // 1. yt-dlp — sin quota, más fiable
  try {
    const query = `${artist} ${track} audio`;
    const { stdout } = await execFileAsync(
      'yt-dlp',
      [
        `ytsearch5:${query}`,
        '--print',
        '%(id)s\t%(title)s',
        '--no-download',
        '--no-playlist',
        '--quiet',
      ],
      { timeout: 10000 }
    );
    const lines = stdout.trim().split('\n').filter(Boolean);
    for (const line of lines) {
      const [videoId, ...titleParts] = line.split('\t');
      const title = titleParts.join('\t');
      if (videoId && !BLOCKED_TITLE.test(title)) {
        const thumb = `https://i.ytimg.com/vi/${videoId}/mqdefault.jpg`;
        return { videoId, channelTitle: '', thumbnail: thumb };
      }
    }
    // Si todos bloqueados, usar el primero
    if (lines.length > 0) {
      const videoId = lines[0].split('\t')[0];
      if (videoId)
        return {
          videoId,
          channelTitle: '',
          thumbnail: `https://i.ytimg.com/vi/${videoId}/mqdefault.jpg`,
        };
    }
  } catch {
    // fallback a YouTube API
  }

  // 2. YouTube Data API v3 (fallback)
  if (!ytKey || ytKey === 'AQUI_VA_TU_API_KEY') return null;
  try {
    const q = `${artist} ${track} audio`;
    const url = new URL('https://www.googleapis.com/youtube/v3/search');
    url.searchParams.set('part', 'snippet');
    url.searchParams.set('q', q);
    url.searchParams.set('maxResults', '5');
    url.searchParams.set('type', 'video');
    url.searchParams.set('key', ytKey);

    const resp = await fetch(url.toString());
    if (!resp.ok) return null;
    const data = await resp.json();
    const items = data.items ?? [];
    const chosen = items.find((i) => !BLOCKED_TITLE.test(i.snippet.title)) ?? items[0];
    if (!chosen) return null;

    return {
      videoId: chosen.id.videoId,
      channelTitle: chosen.snippet.channelTitle,
      thumbnail:
        chosen.snippet.thumbnails.medium?.url ?? chosen.snippet.thumbnails.default?.url ?? '',
    };
  } catch {
    return null;
  }
}

/** Normaliza un track de Last.fm + añade videoId de YouTube */
async function enrichTrack(lfmTrack, ytKey) {
  const artist = lfmTrack.artist?.name ?? lfmTrack.artist ?? '';
  const track = lfmTrack.name ?? '';
  const thumbnail =
    lfmTrack.image?.find((i) => i.size === 'large')?.['#text'] ||
    lfmTrack.image?.find((i) => i.size === 'medium')?.['#text'] ||
    '';

  const yt = await findYouTubeAudio(artist, track, ytKey);
  return {
    title: track,
    artist,
    thumbnail: yt?.thumbnail || thumbnail,
    videoId: yt?.videoId ?? null,
    listeners: lfmTrack.listeners ?? lfmTrack.playcount ?? null,
    url: lfmTrack.url ?? null,
  };
}

// ── GET /api/lastfm/chart/tracks ─────────────────────────────────────────────
router.get('/chart/tracks', async (req, res) => {
  const lfmKey = process.env.LASTFM_API_KEY;
  const ytKey = process.env.YOUTUBE_API_KEY;
  if (!lfmKey) return res.status(500).json({ error: 'LASTFM_API_KEY no configurada' });

  try {
    const api = lfm(lfmKey);
    const data = await api('chart.getTopTracks', { limit: 10 });
    const tracks = data?.tracks?.track ?? [];
    const enriched = await Promise.all(tracks.map((t) => enrichTrack(t, ytKey)));
    res.json(enriched.filter((t) => t.videoId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Placeholder conocido de Last.fm (imagen genérica gris)
const LFM_PLACEHOLDER = '2a96cbd8b46e442fc41c2b86b821562f';
function cleanThumb(url) {
  if (!url || url.includes(LFM_PLACEHOLDER)) return '';
  return url;
}

// ── Obtiene foto de artista vía Deezer (gratis, sin API key, fotos reales) ───
async function deezerArtistPhoto(artistName) {
  try {
    const url = `https://api.deezer.com/search/artist?q=${encodeURIComponent(artistName)}&limit=1`;
    const resp = await fetch(url);
    if (!resp.ok) return '';
    const data = await resp.json();
    return data?.data?.[0]?.picture_xl || data?.data?.[0]?.picture_big || '';
  } catch {
    return '';
  }
}

// ── GET /api/lastfm/chart/artists ────────────────────────────────────────────
// Last.fm quitó imágenes de artista de su API en 2019.
// Usamos Deezer (gratis, sin API key) para obtener fotos reales.
router.get('/chart/artists', async (req, res) => {
  const lfmKey = process.env.LASTFM_API_KEY;
  if (!lfmKey) return res.status(500).json({ error: 'LASTFM_API_KEY no configurada' });

  try {
    const api = lfm(lfmKey);
    const data = await api('chart.getTopArtists', { limit: 10 });
    const rawArtists = data?.artists?.artist ?? [];

    const artists = await Promise.all(
      rawArtists.map(async (a) => ({
        name: a.name,
        listeners: a.listeners,
        thumbnail: await deezerArtistPhoto(a.name),
        url: a.url,
      }))
    );

    res.json(artists);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/lastfm/artist/top?artist=... ────────────────────────────────────
router.get('/artist/top', async (req, res) => {
  const { artist } = req.query;
  if (!artist) return res.status(400).json({ error: 'Falta artist' });
  const lfmKey = process.env.LASTFM_API_KEY;
  const ytKey = process.env.YOUTUBE_API_KEY;
  if (!lfmKey) return res.status(500).json({ error: 'LASTFM_API_KEY no configurada' });

  try {
    const api = lfm(lfmKey);
    const data = await api('artist.getTopTracks', { artist, limit: 8 });
    const tracks = data?.toptracks?.track ?? [];
    const enriched = await Promise.all(tracks.map((t) => enrichTrack(t, ytKey)));
    res.json(enriched.filter((t) => t.videoId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/lastfm/similar?track=&artist= ───────────────────────────────────
router.get('/similar', async (req, res) => {
  const { track, artist } = req.query;
  if (!track || !artist) return res.status(400).json({ error: 'Falta track o artist' });
  const lfmKey = process.env.LASTFM_API_KEY;
  const ytKey = process.env.YOUTUBE_API_KEY;
  if (!lfmKey) return res.status(500).json({ error: 'LASTFM_API_KEY no configurada' });

  try {
    const api = lfm(lfmKey);
    const data = await api('track.getSimilar', { track, artist, limit: 6 });
    const tracks = data?.similartracks?.track ?? [];
    const enriched = await Promise.all(tracks.map((t) => enrichTrack(t, ytKey)));
    res.json(enriched.filter((t) => t.videoId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/lastfm/new-releases ─────────────────────────────────────────────
// Estrategia: toma los artistas top del usuario (de su biblioteca) o globales,
// y obtiene su album más reciente vía Last.fm.
router.get('/new-releases', async (req, res) => {
  const { artists } = req.query; // CSV de nombres de artista
  const lfmKey = process.env.LASTFM_API_KEY;
  const ytKey = process.env.YOUTUBE_API_KEY;
  if (!lfmKey) return res.status(500).json({ error: 'LASTFM_API_KEY no configurada' });

  try {
    const api = lfm(lfmKey);
    let artistList = artists
      ? artists
          .split(',')
          .map((a) => a.trim())
          .filter(Boolean)
      : [];

    // Si no se pasan artistas, usar chart global
    if (artistList.length === 0) {
      const chart = await api('chart.getTopArtists', { limit: 6 });
      artistList = (chart?.artists?.artist ?? []).map((a) => a.name);
    }

    // Para cada artista, obtener su top track más escuchado (proxy de "nuevo lanzamiento popular")
    const results = await Promise.all(
      artistList.slice(0, 6).map(async (artist) => {
        const data = await api('artist.getTopTracks', { artist, limit: 3 });
        const tracks = data?.toptracks?.track ?? [];
        if (!tracks.length) return null;
        const enriched = await enrichTrack(tracks[0], ytKey);
        return enriched.videoId ? enriched : null;
      })
    );

    res.json(results.filter(Boolean));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/lastfm/search?q=... ─────────────────────────────────────────────
// Busca tracks en Last.fm — sin costo de quota YouTube.
// Devuelve resultados con thumbnail de Last.fm pero SIN videoId.
// El cliente debe llamar a /resolve cuando el usuario quiera reproducir.
// ── Obtiene thumbnail de track vía Deezer (portada del álbum, gratis, sin key)
async function deezerTrackThumb(artist, track) {
  try {
    const q = `${artist} ${track}`;
    const url = `https://api.deezer.com/search?q=${encodeURIComponent(q)}&limit=1`;
    const resp = await fetch(url);
    if (!resp.ok) return '';
    const data = await resp.json();
    return data?.data?.[0]?.album?.cover_xl || data?.data?.[0]?.album?.cover_big || '';
  } catch {
    return '';
  }
}

router.get('/search', async (req, res) => {
  const { q, limit = '12' } = req.query;
  if (!q?.trim()) return res.status(400).json({ error: 'Falta q' });
  const lfmKey = process.env.LASTFM_API_KEY;
  if (!lfmKey) return res.status(500).json({ error: 'LASTFM_API_KEY no configurada' });

  try {
    const api = lfm(lfmKey);
    const data = await api('track.search', { track: q.trim(), limit });
    const matches = data?.results?.trackmatches?.track ?? [];

    // Enriquecemos thumbnails con Deezer en paralelo (sin costar quota de YouTube)
    const results = await Promise.all(
      matches.map(async (t) => {
        const lfmThumb = cleanThumb(
          t.image?.find((i) => i.size === 'large')?.['#text'] ||
            t.image?.find((i) => i.size === 'medium')?.['#text'] ||
            ''
        );
        const thumbnail = lfmThumb || (await deezerTrackThumb(t.artist, t.name));
        return {
          title: t.name,
          artist: t.artist,
          thumbnail,
          videoId: null, // lazy — se resuelve con /resolve
          listeners: t.listeners ?? null,
          url: t.url ?? null,
        };
      })
    );

    res.json(results);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/lastfm/resolve?track=&artist= ───────────────────────────────────
// Resuelve el videoId de YouTube para una canción concreta.
// Se llama solo cuando el usuario quiere reproducir (lazy).
// Costo: 100 unidades de quota de YouTube por llamada.
router.get('/resolve', async (req, res) => {
  const { track, artist } = req.query;
  if (!track || !artist) return res.status(400).json({ error: 'Falta track o artist' });
  const ytKey = process.env.YOUTUBE_API_KEY;
  const result = await findYouTubeAudio(artist, track, ytKey);
  if (!result) return res.status(404).json({ error: 'No se encontró en YouTube' });
  res.json(result);
});

export default router;
