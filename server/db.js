/**
 * espotifai — Base de datos simple basada en JSON
 * Persiste la biblioteca en server/data/library.json
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = join(__dirname, 'data');
const DB_PATH = join(DATA_DIR, 'library.json');

function ensureDb() {
  if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });
  if (!existsSync(DB_PATH)) writeFileSync(DB_PATH, '[]', 'utf-8');
}

export function getLibrary() {
  ensureDb();
  return JSON.parse(readFileSync(DB_PATH, 'utf-8'));
}

function saveLibrary(data) {
  ensureDb();
  writeFileSync(DB_PATH, JSON.stringify(data, null, 2), 'utf-8');
}

export function addToLibrary(item) {
  const lib = getLibrary();
  if (lib.find((t) => t.videoId === item.videoId)) return null; // ya existe
  lib.unshift(item);
  saveLibrary(lib);
  return item;
}

export function removeFromLibrary(videoId) {
  const lib = getLibrary();
  const idx = lib.findIndex((t) => t.videoId === videoId);
  if (idx === -1) return false;
  lib.splice(idx, 1);
  saveLibrary(lib);
  return true;
}

export function updateTrack(videoId, updates) {
  const lib = getLibrary();
  const idx = lib.findIndex((t) => t.videoId === videoId);
  if (idx === -1) return null;
  lib[idx] = { ...lib[idx], ...updates };
  saveLibrary(lib);
  return lib[idx];
}
