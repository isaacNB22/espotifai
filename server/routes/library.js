/**
 * GET    /api/library          → lista la biblioteca
 * POST   /api/library          → agrega un track
 * DELETE /api/library/:videoId → elimina un track
 * POST   /api/library/import   → importa desde URL de YouTube (video o playlist)
 */

import { Router } from 'express';
import { existsSync } from 'fs';
import { getLibrary, addToLibrary, removeFromLibrary } from '../db.js';
import YTDlpWrapModule from 'yt-dlp-wrap';
const YTDlpWrap = YTDlpWrapModule.default ?? YTDlpWrapModule;

const router = Router();

// ── Importar por URL (antes que la ruta POST /) ────────────────────────────
router.post('/import', async (req, res) => {
  const { url } = req.body;
  if (!url || typeof url !== 'string') {
    return res.status(400).json({ error: 'Se requiere una URL válida' });
  }

  try {
    const ytDlp = new YTDlpWrap();

    // Obtiene metadata (puede ser playlist o video individual)
    const raw = await ytDlp.getVideoInfo(url);

    // Si es playlist devuelve entries[], si es video devuelve el objeto directo
    const entries = raw.entries ?? [raw];

    const added = [];
    for (const entry of entries) {
      if (!entry.id || !entry.title) continue;
      const thumbnail =
        entry.thumbnail ??
        entry.thumbnails?.at(-1)?.url ??
        `https://i.ytimg.com/vi/${entry.id}/mqdefault.jpg`;
      const item = addToLibrary({
        videoId: entry.id,
        title: entry.title,
        author: entry.uploader ?? entry.channel ?? '',
        thumbnail,
        addedAt: new Date().toISOString(),
        downloadStatus: 'pending',
        filename: null,
        duration: entry.duration ?? null,
      });
      if (item) added.push(item); // null si ya existe → lo ignoramos
    }

    res.json(added);
  } catch (err) {
    console.error('[library/import]', err.message);
    res
      .status(500)
      .json({ error: 'No se pudo obtener información de la URL. Verifica que sea válida.' });
  }
});

router.get('/', (_req, res) => {
  res.json(getLibrary());
});

router.post('/', (req, res) => {
  const { videoId, title, author, thumbnail } = req.body;

  if (!videoId || !title) {
    return res.status(400).json({ error: 'videoId y title son requeridos' });
  }

  const item = addToLibrary({
    videoId,
    title,
    author: author ?? '',
    thumbnail: thumbnail ?? '',
    addedAt: new Date().toISOString(),
    downloadStatus: 'pending',
    filename: null,
  });

  if (!item) return res.status(409).json({ error: 'Ya existe en la biblioteca' });

  res.status(201).json(item);
});

router.delete('/:videoId', (req, res) => {
  const removed = removeFromLibrary(req.params.videoId);
  if (!removed) return res.status(404).json({ error: 'Track no encontrado' });
  res.json({ ok: true });
});

export default router;
