import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { env } from '../config/env.js';

/**
 * Penyimpanan kurs `GET /rates` (F-17, WF-05 — deskripsi Bagian 5.12).
 *
 * Kurs disimpan sebagai `rate_to_idr` (berapa IDR untuk 1 unit mata uang)
 * — bentuk yang sama dengan tabel `rate_cache` klien. Provider publik
 * tanpa API key (keputusan 18: proyek $0) dipanggil bila cache kedaluwarsa;
 * kegagalan jaringan jatuh ke cache terakhir, lalu ke nilai statis.
 *
 * File `backend/data/rates.json` di-gitignore (lihat `.gitignore`).
 */

const defaultDataDir = fileURLToPath(new URL('../../data', import.meta.url));

/** Kurs cadangan statis — dipakai saat provider tak terjangkau & saat test. */
export const FALLBACK_RATES = Object.freeze({
  USD: 16300,
  EUR: 17600,
  JPY: 104,
});

/** Mata uang yang wajib tersedia (kontrak minimal SCR-04). */
export const CURRENCIES = Object.freeze(['USD', 'EUR', 'JPY']);

function ratesFile() {
  const dir = process.env.DATA_DIR ?? defaultDataDir;
  return join(dir, 'rates.json');
}

function loadCache() {
  const file = ratesFile();
  if (!existsSync(file)) return null;
  try {
    const parsed = JSON.parse(readFileSync(file, 'utf8'));
    if (!parsed || typeof parsed !== 'object' || !parsed.rates) return null;
    return parsed;
  } catch (_) {
    return null;
  }
}

function saveCache(rates, fetchedAt) {
  const file = ratesFile();
  try {
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, JSON.stringify({ rates, fetchedAt }, null, 2), 'utf8');
  } catch (_) {
    // Disk penuh/ditolak: cache memori tetap dipakai untuk sesi berjalan.
  }
}

/**
 * Mengubah balasan provider (basis IDR, `1 unit = berapa IDR`) menjadi
 * bentuk `rate_to_idr`; provider basis lain (mis. USD) ikut ditangani.
 */
function normalize(providerRates, base) {
  if (!providerRates || typeof providerRates !== 'object') return null;
  const baseRate = Number(providerRates[base]);
  const result = {};
  for (const code of CURRENCIES) {
    if (code === base) {
      result[code] = 1;
      continue;
    }
    const value = Number(providerRates[code]);
    // rate_to_idr(kode) = IDR per 1 kode = (IDR per 1 base) / (kode per 1 base).
    const perBase = Number.isFinite(value) && value > 0 ? value : null;
    const idrPerBase = Number.isFinite(baseRate) && baseRate > 0 ? baseRate : null;
    if (perBase === null || idrPerBase === null) return null;
    result[code] = idrPerBase / perBase;
  }
  return result;
}

let cache = loadCache();
let inFlight = null;

/** Ambil kurs segar bila cache kedaluwarsa; selalu terbaik-suai. */
async function refresh() {
  const now = Date.now();
  if (cache && now - cache.fetchedAt < env.ratesTtlMs) return cache;
  if (env.ratesOffline) {
    // Mode luring: pakai cache terakhir, atau nilai statis bila belum ada.
    if (cache) return cache;
    cache = { rates: { ...FALLBACK_RATES }, fetchedAt: now };
    return cache;
  }
  if (inFlight) return inFlight;
  inFlight = (async () => {
    try {
      const response = await fetch(env.ratesProviderUrl, {
        signal: AbortSignal.timeout(5000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const body = await response.json();
      const rates = normalize(body.rates, body.base ?? 'IDR');
      if (!rates) throw new Error('balasan provider tidak lengkap');
      cache = { rates, fetchedAt: Date.now() };
      saveCache(rates, cache.fetchedAt);
    } catch (_) {
      // Provider gagal → pakai cache lama; kalau belum ada, nilai statis.
      if (!cache) cache = { rates: { ...FALLBACK_RATES }, fetchedAt: 0 };
    } finally {
      inFlight = null;
    }
    return cache;
  })();
  return inFlight;
}

/** Kurs untuk dibalas ke klien: `{ rates, fetchedAt }`. */
export async function getRates() {
  const current = await refresh();
  return { rates: { ...current.rates }, fetchedAt: current.fetchedAt };
}
