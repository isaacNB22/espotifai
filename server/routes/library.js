/**
 * GET    /api/library          → lista la biblioteca
 * POST   /api/library          → agrega un track
 * DELETE /api/library/:videoId → elimina un track
 */

import { Router } from 'express';
import { getLibrary, addToLibrary, removeFromLibrary } from '../db.js';

const router = Router();

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
    downloadStatus: 'pending', // pending | downloading | done | error
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
