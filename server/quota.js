/**
 * espotifai — Quota tracker
 * Cada búsqueda cuesta 100 unidades. Límite diario: 10,000 = 100 búsquedas.
 * Se persiste en server/data/quota.json y se resetea automáticamente cada día.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = join(__dirname, 'data');
const DB_PATH = join(DATA_DIR, 'quota.json');

const DAILY_LIMIT = 10_000; // unidades
const SEARCH_COST = 100; // unidades por búsqueda

function today() {
  return new Date().toISOString().slice(0, 10); // "2026-05-02"
}

function load() {
  if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });
  if (!existsSync(DB_PATH)) return { date: today(), used: 0 };
  try {
    return JSON.parse(readFileSync(DB_PATH, 'utf-8'));
  } catch {
    return { date: today(), used: 0 };
  }
}

function save(data) {
  writeFileSync(DB_PATH, JSON.stringify(data, null, 2), 'utf-8');
}

/** Registra una búsqueda (100 unidades). Devuelve el estado actualizado. */
export function recordSearch() {
  const data = load();
  if (data.date !== today()) {
    data.date = today();
    data.used = 0;
  }
  data.used = Math.min(data.used + SEARCH_COST, DAILY_LIMIT);
  save(data);
  return getQuotaStatus();
}

/** Devuelve el estado actual de la quota. */
export function getQuotaStatus() {
  const data = load();
  if (data.date !== today()) {
    return { used: 0, limit: DAILY_LIMIT, remaining: DAILY_LIMIT, percent: 0, resetDate: today() };
  }
  const remaining = Math.max(0, DAILY_LIMIT - data.used);
  const percent = Math.round((data.used / DAILY_LIMIT) * 100);
  return { used: data.used, limit: DAILY_LIMIT, remaining, percent, resetDate: data.date };
}
