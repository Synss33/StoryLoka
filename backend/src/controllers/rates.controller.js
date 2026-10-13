import { getRates } from '../services/rate.store.js';

/**
 * GET /rates — kurs mata uang untuk konverter SCR-04 (F-17, WF-05).
 *
 * Balasan: `{ rates: { USD, EUR, JPY }, fetchedAt, serverTime }` —
 * `rates` bernilai IDR per 1 unit mata uang (sama dengan kolom
 * `rate_cache` klien). Klien menyimpan balasan ini sebagai cache offline
 * dan menampilkan "diperbarui …" dari `fetchedAt`.
 *
 * Dilindungi `requireAuth` oleh route.
 */
export async function getRatesHandler(req, res, next) {
  try {
    const { rates, fetchedAt } = await getRates();
    res.status(200).json({
      rates,
      fetchedAt,
      serverTime: Date.now(),
    });
  } catch (error) {
    next(error);
  }
}
