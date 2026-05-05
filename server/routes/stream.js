/**
 * GET /api/stream/:videoId  — Streaming de audio
 * 1. Si el track está descargado → sirve el archivo local con Range support
 * 2. Si no está descargado       → proxy stream desde YouTube vía yt-dlp
 */

import { Router } from 'express';
import { createReadStream, existsSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';
import { getLibrary } from '../db.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DOWNLOADS_DIR = join(__dirname, '..', 'downloads');

// Misma lógica de búsqueda de yt-dlp que download.js
const YT_DLP_PATHS = [
  'yt-dlp',
  'yt-dlp.exe',
  `${process.env.LOCALAPPDATA}\\Packages\\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\\LocalCache\\local-packages\\Python311\\Scripts\\yt-dlp.exe`,
  `${process.env.LOCALAPPDATA}\\Microsoft\\WinGet\\Packages\\yt-dlp.yt-dlp_Microsoft.Winget.Source_8wekyb3d8bbwe\\yt-dlp.exe`,
  `${process.env.APPDATA}\\Python\\Scripts\\yt-dlp.exe`,
];
let ytDlpBin = 'yt-dlp';
for (const p of YT_DLP_PATHS) {
  if (p && existsSync(p)) {
    ytDlpBin = p;
    break;
  }
}

const router = Router();

router.get('/:videoId', (req, res) => {
  const { videoId } = req.params;
  const safeId = videoId.replace(/[^a-zA-Z0-9_-]/g, '');
  if (!safeId) return res.status(400).json({ error: 'videoId inválido' });

  const lib = getLibrary();
  const track = lib.find((t) => t.videoId === safeId);

  // ── 1. Archivo descargado: stream local con Range support ──
  if (track?.filename) {
    const filePath = join(DOWNLOADS_DIR, track.filename);
    if (existsSync(filePath)) {
      const stat = statSync(filePath);
      const total = stat.size;
      const contentType = track.filename.endsWith('.mp4') ? 'video/mp4' : 'audio/mpeg';
      const range = req.headers.range;

      if (range) {
        const [startStr, endStr] = range.replace(/bytes=/, '').split('-');
        const start = parseInt(startStr, 10);
        const end = endStr ? parseInt(endStr, 10) : total - 1;
        const chunk = end - start + 1;
        res.writeHead(206, {
          'Content-Range': `bytes ${start}-${end}/${total}`,
          'Accept-Ranges': 'bytes',
          'Content-Length': chunk,
          'Content-Type': contentType,
        });
        createReadStream(filePath, { start, end }).pipe(res);
      } else {
        res.writeHead(200, {
          'Content-Length': total,
          'Content-Type': contentType,
          'Accept-Ranges': 'bytes',
        });
        createReadStream(filePath).pipe(res);
      }
      return;
    }
  }

  // ── 2. No descargado: yt-dlp → stream directo ──
  const ytUrl = `https://www.youtube.com/watch?v=${safeId}`;

  res.setHeader('Content-Type', 'audio/mpeg');
  res.setHeader('Transfer-Encoding', 'chunked');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('X-Stream-Source', 'yt-dlp-proxy');

  // yt-dlp extrae el audio y lo convierte a mp3 (usa ffmpeg integrado si disponible,
  // o entrega el formato nativo m4a/webm si no lo hay)
  const ytProc = spawn(ytDlpBin, [
    '--no-playlist',
    '-f',
    'bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio/best',
    '--no-check-formats',
    '--extractor-args',
    'youtube:player_client=android,mweb',
    '--no-check-certificates',
    '--retries',
    '3',
    '--add-header',
    'Accept-Language:en-US,en;q=0.9',
    '-o',
    '-',
    '--quiet',
    ytUrl,
  ]);

  // Intentar pasar por ffmpeg para normalizar a mp3; si no existe, stream raw
  let ffProc;
  try {
    ffProc = spawn('ffmpeg', [
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      'pipe:0',
      '-vn',
      '-acodec',
      'libmp3lame',
      '-ab',
      '128k',
      '-f',
      'mp3',
      'pipe:1',
    ]);
    ytProc.stdout.pipe(ffProc.stdin);
    ffProc.stdout.pipe(res);
    ffProc.stdin.on('error', () => {});
    ffProc.stdout.on('error', () => {});
    ffProc.stderr.on('data', (d) => {
      const msg = d.toString().trim();
      if (msg) console.warn('[stream/ffmpeg]', msg);
    });
    ffProc.on('error', (err) => {
      // ffmpeg no disponible: fallback a raw
      console.warn('[stream] ffmpeg no disponible, enviando audio raw:', err.message);
      if (!ffProc.killed) ffProc.kill('SIGTERM');
      if (!res.headersSent) {
        res.setHeader('Content-Type', 'audio/mp4');
        ytProc.stdout.pipe(res);
      }
    });
    ffProc.on('close', () => {
      if (!res.writableEnded) res.end();
    });
  } catch (_) {
    // spawn mismo falló: stream raw
    ytProc.stdout.pipe(res);
  }

  ytProc.stderr.on('data', (d) => {
    const msg = d.toString().trim();
    if (msg) console.warn('[stream/yt-dlp]', msg);
  });

  const cleanup = () => {
    if (!ytProc.killed) ytProc.kill('SIGTERM');
    if (ffProc && !ffProc.killed) ffProc.kill('SIGTERM');
  };

  ytProc.on('error', (err) => {
    console.error('[stream/yt-dlp] spawn error:', err.message);
    cleanup();
    if (!res.headersSent) res.status(500).end();
    else res.destroy();
  });

  req.on('close', cleanup);
});

export default router;
