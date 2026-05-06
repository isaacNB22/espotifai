import { Router } from 'express';
import { createReadStream, existsSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';
import { getLibrary } from '../db.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DOWNLOADS_DIR = join(__dirname, '..', 'downloads');

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

const urlCache = new Map();
const CACHE_TTL = 2 * 60 * 60 * 1000;

const router = Router();

router.get('/:videoId', async (req, res) => {
  const { videoId } = req.params;
  const safeId = videoId.replace(/[^a-zA-Z0-9_-]/g, '');
  if (!safeId) return res.status(400).json({ error: 'videoId invalido' });

  console.log(`[stream] GET /${safeId} range=${req.headers.range || 'none'}`);

  const lib = getLibrary();
  const track = lib.find((t) => t.videoId === safeId);

  if (track?.filename) {
    const filePath = join(DOWNLOADS_DIR, track.filename);
    if (existsSync(filePath)) {
      const stat = statSync(filePath);
      const total = stat.size;
      const contentType = track.filename.endsWith('.mp4') ? 'video/mp4' : 'audio/mpeg';
      const range = req.headers.range;
      if (range) {
        const [s, e] = range.replace(/bytes=/, '').split('-');
        const start = parseInt(s, 10);
        const end = e ? parseInt(e, 10) : total - 1;
        res.writeHead(206, {
          'Content-Range': `bytes ${start}-${end}/${total}`,
          'Accept-Ranges': 'bytes',
          'Content-Length': end - start + 1,
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

  const ytUrl = `https://www.youtube.com/watch?v=${safeId}`;
  const cached = urlCache.get(safeId);
  if (cached && cached.exp > Date.now()) {
    console.log('[stream] usando URL cacheada');
    return proxyAudio(req, res, cached.url);
  }

  try {
    const audioUrl = await getDirectUrl(ytUrl);
    urlCache.set(safeId, { url: audioUrl, exp: Date.now() + CACHE_TTL });
    return proxyAudio(req, res, audioUrl);
  } catch (err) {
    console.error('[stream/ytdlp]', err.message?.split('\n')[0]);
    if (!res.headersSent) res.status(502).json({ error: 'No se pudo reproducir la cancion' });
  }
});

function getDirectUrl(ytUrl) {
  return new Promise((resolve, reject) => {
    const baseArgs = [
      '--no-playlist',
      '-f',
      'bestaudio[protocol!=m3u8][protocol!=m3u8_native][acodec!=none][vcodec=none]/bestaudio[protocol!=m3u8][protocol!=m3u8_native]/bestaudio',
      '--no-check-certificates',
      '--extractor-args',
      'youtube:player_client=android,web',
      '--get-url',
      '--quiet',
    ];
    // Intentar con cada navegador hasta que uno funcione
    const browsers = ['edge', 'firefox'];
    let attempt = -1; // -1 = sin cookies primero

    function tryNext() {
      attempt++;
      const browser = attempt < browsers.length ? browsers[attempt - 1] : null;
      const args = [...baseArgs];
      if (attempt > 0 && browser) args.push('--cookies-from-browser', browser);
      if (attempt > browsers.length) return reject(new Error('No se pudo obtener URL'));

      const label = attempt === 0 ? 'sin cookies' : browser;
      console.log(`[stream] yt-dlp intento ${attempt + 1}: ${label}`);
      const proc = spawn(ytDlpBin, [...args, ytUrl]);
      let out = '',
        err = '';
      proc.stdout.on('data', (d) => (out += d.toString()));
      proc.stderr.on('data', (d) => (err += d.toString()));
      proc.on('close', () => {
        const url = out.trim().split('\n')[0];
        if (url) {
          console.log(`[stream] URL obtenida con: ${label}`);
          resolve(url);
        } else {
          console.log(`[stream] fallo ${label}: ${err.split('\n')[0]}`);
          tryNext();
        }
      });
      proc.on('error', () => tryNext());
    }
    tryNext();
  });
}

async function proxyAudio(req, res, audioUrl, isRetry = false) {
  // Si la URL es HLS y no es reintento, dejarla pasar a mpv directamente via redirect
  const isHls =
    audioUrl.includes('manifest.googlevideo.com') ||
    audioUrl.includes('.m3u8') ||
    audioUrl.includes('hls_playlist');
  if (isHls && !isRetry) {
    console.log('[stream] HLS detectado en proxy, redirigiendo a mpv');
    return res.redirect(302, audioUrl);
  }
  const { default: https } = await import('https');
  const { default: http } = await import('http');
  const protocol = audioUrl.startsWith('https') ? https : http;
  const upstreamHeaders = { 'User-Agent': 'Mozilla/5.0' };
  if (req.headers.range) upstreamHeaders['Range'] = req.headers.range;
  const proxyReq = protocol.get(audioUrl, { headers: upstreamHeaders }, (proxyRes) => {
    console.log(
      `[stream] proxy status=${proxyRes.statusCode} type=${proxyRes.headers['content-type']}`
    );
    const headers = {
      'Content-Type': proxyRes.headers['content-type'] || 'audio/mp4',
      'Accept-Ranges': 'bytes',
    };
    if (proxyRes.headers['content-length'])
      headers['Content-Length'] = proxyRes.headers['content-length'];
    if (proxyRes.headers['content-range'])
      headers['Content-Range'] = proxyRes.headers['content-range'];
    res.writeHead(proxyRes.statusCode || 200, headers);
    proxyRes.pipe(res);
    res.on('close', () => proxyReq.destroy());
  });
  proxyReq.on('error', (e) => {
    console.error('[stream/proxy]', e.message);
    if (!res.headersSent) res.status(502).end();
  });
}

export default router;
