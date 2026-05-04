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

// Health check
app.get('/api/ping', (_req, res) => res.json({ ok: true, version: '1.0.0' }));

app.listen(PORT, () => {
  console.log(`
  ╔══════════════════════════════════════════╗
  ║   espotifai API  →  http://localhost:${PORT}  ║
  ╚══════════════════════════════════════════╝
  `);
});
