import {
  AiError,
  chatCompletion,
  recommendBooks,
  summarizeBook,
} from '../services/ai.service.js';

/**
 * Handler proxy AI (F-11 / WF-07). Semua endpoint dilindungi `requireAuth`
 * oleh route-nya. Galat [AiError] dibalas sesuai statusnya agar klien bisa
 * membedakan kuota (429) / timeout (504) / layanan mati (503) / gagal (502).
 */

function aiErrorResponder(error, res, next) {
  if (error instanceof AiError) {
    res.status(error.status).json({
      error: { code: error.code, message: error.message },
    });
    return;
  }
  next(error);
}

function badRequest(res, message) {
  res.status(400).json({ error: { code: 'BAD_REQUEST', message } });
}

/**
 * POST /ai/chat — asisten tanya-jawab SCR-05 (workflow Bagian 3.5).
 * Body: `{ message, history?, context? }` → balas `{ reply, serverTime }`.
 */
export async function chatHandler(req, res, next) {
  try {
    const body = req.body ?? {};
    const message = typeof body.message === 'string' ? body.message.trim() : '';
    if (!message) return badRequest(res, 'message wajib diisi.');
    const reply = await chatCompletion({
      message,
      history: body.history,
      context: typeof body.context === 'string' ? body.context.slice(0, 500) : undefined,
    });
    res.status(200).json({ reply, serverTime: Date.now() });
  } catch (error) {
    aiErrorResponder(error, res, next);
  }
}

/**
 * POST /ai/summarize — ringkasan buku SCR-06 (Bagian 5.6; hasil klien
 * di-cache lokal). Body: `{ title, author, synopsis?, notes? }`
 * → balas `{ summary, serverTime }`.
 */
export async function summarizeHandler(req, res, next) {
  try {
    const body = req.body ?? {};
    const title = typeof body.title === 'string' ? body.title.trim() : '';
    if (!title) return badRequest(res, 'title wajib diisi.');
    const summary = await summarizeBook({
      title,
      author: typeof body.author === 'string' ? body.author : '',
      synopsis: typeof body.synopsis === 'string' ? body.synopsis.slice(0, 4000) : '',
      notes: Array.isArray(body.notes) ? body.notes : undefined,
    });
    res.status(200).json({ summary, serverTime: Date.now() });
  } catch (error) {
    aiErrorResponder(error, res, next);
  }
}

/**
 * POST /ai/recommend — buku mirip berdasarkan genre & rating riwayat
 * (Bagian 5.6). Body: `{ books: [{ title, author?, genre?, rating? }] }`
 * → balas `{ recommendations, serverTime }` (teks berbaris).
 */
export async function recommendHandler(req, res, next) {
  try {
    const body = req.body ?? {};
    const recommendations = await recommendBooks({ books: body.books });
    res.status(200).json({ recommendations, serverTime: Date.now() });
  } catch (error) {
    aiErrorResponder(error, res, next);
  }
}
