/**
 * POST /api/download           → inicia descarga, devuelve { jobId }
 * GET  /api/download/status/:jobId → estado del job
 * GET  /api/download/file/:videoId → descarga el archivo guardado
 */

import { Router } from 'express';
import { createReadStream, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import YTDlpWrapModule from 'yt-dlp-wrap';
const YTDlpWrap = YTDlpWrapModule.default ?? YTDlpWrapModule;
import { v4 as uuidv4 } from 'uuid';
import { updateTrack, getLibrary } from '../db.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

const DOWNLOADS_DIR = process.env.DOWNLOADS_DIR
  ? join(process.cwd(), process.env.DOWNLOADS_DIR)
  : join(__dirname, '..', 'downloads');

if (!existsSync(DOWNLOADS_DIR)) mkdirSync(DOWNLOADS_DIR, { recursive: true });

// Buscar yt-dlp en PATH o en ubicaciones conocidas de pip/winget
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

const ytDlp = new YTDlpWrap(ytDlpBin);

// Mapa en memoria de jobs activos: jobId → { status, progress, videoId, error }
const jobs = new Map();

const router = Router();

// ── Iniciar descarga ──────────────────────────────────────────────────────────
router.post('/', async (req, res) => {
  const { videoId, format = 'mp3' } = req.body;
  if (!videoId) return res.status(400).json({ error: 'videoId requerido' });

  const jobId = uuidv4();
  const safeId = videoId.replace(/[^a-zA-Z0-9_-]/g, '');
  const ext = format === 'mp4' ? 'mp4' : 'mp3';
  const filename = `${safeId}.${ext}`;
  const outPath = join(DOWNLOADS_DIR, filename);

  jobs.set(jobId, { status: 'downloading', progress: 0, videoId, error: null });
  updateTrack(videoId, { downloadStatus: 'downloading' });

  // Responde inmediatamente con el jobId
  res.json({ jobId });

  // Descarga en segundo plano
  const ytUrl = `https://www.youtube.com/watch?v=${safeId}`;

  // Args base
  const baseArgs = [ytUrl, '--no-check-formats', '--no-check-certificates', '-o', outPath];

  const args =
    format === 'mp4'
      ? [...baseArgs, '-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best']
      : [...baseArgs, '-x', '--audio-format', 'mp3', '--audio-quality', '0'];

  try {
    // Escucha el progreso de yt-dlp
    const proc = ytDlp.exec(args);
    proc.on('ytDlpEvent', (eventType, eventData) => {
      if (eventType === 'download') {
        const match = eventData.match(/(\d{1,3}(?:\.\d+)?%)/);
        if (match) {
          const pct = parseFloat(match[1]);
          jobs.set(jobId, { status: 'downloading', progress: pct, videoId, error: null });
        }
      }
    });
    await new Promise((resolve, reject) => {
      proc.on('close', resolve);
      proc.on('error', reject);
    });

    jobs.set(jobId, { status: 'done', progress: 100, videoId, error: null });
    updateTrack(videoId, { downloadStatus: 'done', filename });
  } catch (err) {
    jobs.set(jobId, { status: 'error', progress: 0, videoId, error: err.message });
    updateTrack(videoId, { downloadStatus: 'error' });
  }
});

// ── Estado del job (JSON) ─────────────────────────────────────────────────────
router.get('/status/:jobId', (req, res) => {
  const job = jobs.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'Job no encontrado' });
  res.json(job);
});

// ── SSE: progreso en tiempo real ──────────────────────────────────────────────
router.get('/progress/:jobId', (req, res) => {
  const { jobId } = req.params;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  const send = () => {
    const job = jobs.get(jobId);
    if (!job) {
      res.write('event: error\ndata: {"error":"Job no encontrado"}\n\n');
      res.end();
      return;
    }
    res.write(`data: ${JSON.stringify(job)}\n\n`);
    if (job.status === 'done' || job.status === 'error') {
      res.end();
      clearInterval(iv);
    }
  };

  send();
  const iv = setInterval(send, 500);
  req.on('close', () => clearInterval(iv));
});

// ── Descargar archivo guardado ────────────────────────────────────────────────
router.get('/file/:videoId', (req, res) => {
  const lib = getLibrary();
  const track = lib.find((t) => t.videoId === req.params.videoId);

  if (!track?.filename) return res.status(404).json({ error: 'Archivo no en biblioteca' });

  const filePath = join(DOWNLOADS_DIR, track.filename);
  if (!existsSync(filePath)) return res.status(404).json({ error: 'Archivo no existe en disco' });

  const contentType = track.filename.endsWith('.mp3') ? 'audio/mpeg' : 'video/mp4';
  res.setHeader('Content-Type', contentType);
  res.setHeader(
    'Content-Disposition',
    `attachment; filename*=UTF-8''${encodeURIComponent(track.filename)}`
  );
  createReadStream(filePath).pipe(res);
});

export default router;
