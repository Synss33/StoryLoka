import { readFeedback, saveFeedback } from '../services/sync.store.js';

/** 400 untuk payload yang salah bentuk. */
function badRequest(res, message) {
  res.status(400).json({ error: { code: 'INVALID_INPUT', message } });
}

function asText(value) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

/**
 * POST /feedback — kesan & saran mata kuliah PAM (F-08, WF-04).
 *
 * Body: { kesan?, saran?, updated_at? }. Validasi: minimal satu kolom
 * terisi; konflik diselesaikan *last-write-wins* per pengguna.
 * Dilindungi `requireAuth` oleh route.
 */
export function postFeedback(req, res) {
  const body = req.body ?? {};
  const kesan = asText(body.kesan);
  const saran = asText(body.saran);
  if (kesan === undefined || saran === undefined) {
    badRequest(res, "Field 'kesan'/'saran' harus berupa teks.");
    return;
  }
  if (kesan === null && saran === null) {
    badRequest(res, 'Isi minimal satu kolom (kesan atau saran).');
    return;
  }

  const updatedAt = Number.isFinite(Number(body.updated_at))
    ? Number(body.updated_at)
    : Date.now();

  saveFeedback(req.user.id, {
    kesan,
    saran,
    updated_at: updatedAt,
  });

  res.status(200).json({ ok: true, serverTime: Date.now() });
}

/**
 * GET /feedback — isi kesan/saran terakhir milik pengguna
 * (dipakai klien bila data lokal masih kosong).
 */
export function getFeedback(req, res) {
  res.status(200).json({
    feedback: readFeedback(req.user.id),
    serverTime: Date.now(),
  });
}
