/**
 * espotifai — Servidor Express
 * Levanta la API y sirve el frontend estático
 *
 * Uso:
 *   cd server
 *   npm install
 *   cp .env.example .env   ← completa YOUTUBE_API_KEY
 *   npm run dev
 *
 * Requiere yt-dlp instalado: https://github.com/yt-dlp/yt-dlp#installation
 */

import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import searchRouter from './routes/search.js';
import libraryRouter from './routes/library.js';
import downloadRouter from './routes/download.js';
import streamRouter from './routes/stream.js';
import lastfmRouter from './routes/lastfm.js';
import deezerRouter from './routes/deezer.js';
import { getQuotaStatus } from './quota.js';
import { getLibrary } from './db.js';

// Evitar que errores EPIPE (cliente desconectado durante streaming) tiren el servidor
process.on('uncaughtException', (err) => {
  if (err.code === 'EPIPE') return; // ignorar silenciosamente
  console.error('[uncaughtException]', err);
});

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT ?? 3000);

const app = express();

// Permite peticiones desde el frontend abierto como archivo local o en otro puerto
app.use(
  cors({
    origin: [
      'http://localhost:5500',
      'http://127.0.0.1:5500',
      `http://localhost:${PORT}`,
      'null', // file:// origin
    ],
  })
);

app.use(express.json());

// Sirve los archivos estáticos del frontend (carpeta raíz del proyecto)
app.use(express.static(join(__dirname, '..')));

// ── Rutas de la API ───────────────────────────────────────────────────────────
app.use('/api/search', searchRouter);
app.use('/api/library', libraryRouter);
app.use('/api/download', downloadRouter);
app.use('/api/stream', streamRouter);
app.use('/api/lastfm', lastfmRouter);
app.use('/api/deezer', deezerRouter);

// Health check
app.get('/api/ping', (_req, res) => res.json({ ok: true, version: '1.0.0' }));

// Stats
app.get('/api/stats', (_req, res) => {
  const library = getLibrary();
  const quota = getQuotaStatus();
  res.json({
    totalSongs: library.length,
    downloaded: library.filter((s) => s.downloadStatus === 'done').length,
    quota,
  });
});

app.listen(PORT, () => {
  console.log(`
  ╔══════════════════════════════════════════╗
  ║   espotifai API  →  http://localhost:${PORT}  ║
  ╚══════════════════════════════════════════╝
  `);
});
