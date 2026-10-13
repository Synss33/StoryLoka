import { applyChanges, snapshot } from '../services/sync.store.js';

const ARRAY_FIELDS = [
  'books',
  'sessions',
  'notes',
  'reviews',
  'blocks',
  'feedback',
];

/** 400 untuk payload yang salah bentuk. */
function badRequest(res, message) {
  res.status(400).json({ error: { code: 'INVALID_INPUT', message } });
}

/**
 * POST /sync — sinkronisasi dua arah (deskripsi Bagian 5.2, WF-03).
 *
 * Permintaan: { since, books[], sessions[], notes[], reviews[], blocks[],
 *               feedback[], settings } — hanya data lokal yang `dirty`.
 * Balasan  : { serverTime, books[], sessions[], ..., settings } — snapshot
 *            penuh milik pengguna; klien menerapkan *last-write-wins*.
 *
 * Dilindungi `requireAuth` (token sesi) oleh route.
 */
export function sync(req, res) {
  const body = req.body ?? {};
  for (const field of ARRAY_FIELDS) {
    if (body[field] !== undefined && !Array.isArray(body[field])) {
      badRequest(res, `Field '${field}' harus berupa array.`);
      return;
    }
  }
  if (
    body.settings !== undefined &&
    body.settings !== null &&
    typeof body.settings !== 'object'
  ) {
    badRequest(res, "Field 'settings' harus berupa objek.");
    return;
  }

  const payload = {};
  for (const field of ARRAY_FIELDS) {
    payload[field] = Array.isArray(body[field]) ? body[field] : [];
  }
  payload.settings =
    body.settings && typeof body.settings === 'object' ? body.settings : null;

  const userId = req.user.id;
  applyChanges(userId, payload);

  res.status(200).json({
    serverTime: Date.now(),
    ...snapshot(userId),
  });
}
