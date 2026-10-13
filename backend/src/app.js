import cors from 'cors';
import express from 'express';

import { errorHandler, notFoundHandler } from './middleware/error.handler.js';
import authRouter from './routes/auth.route.js';
import healthRouter from './routes/health.route.js';
import syncRouter from './routes/sync.route.js';

/**
 * Membuat instance aplikasi Express (terpisah dari proses listen agar
 * bisa dipakai unit test tanpa membuka port).
 *
 * Endpoint:
 *   GET /health            -> status layanan (WF-01)
 *   POST /auth/register    -> buat akun (WF-02)
 *   POST /auth/login       -> sesi token (WF-02)
 *   POST /auth/logout      -> akhiri sesi (WF-02, butuh Bearer token)
 *   POST /sync             -> sinkronisasi dua arah (WF-03, Bearer token)
 * Endpoint lain (/feedback, /ai/*, /rates) menyusul di
 * WF-04…WF-07 sesuai `docs/deskripsi_proyek.md` Bagian 5.2.
 */
export function createApp() {
  const app = express();

  app.use(cors());
  // Batas body 1 MB; JSON only (klien Flutter mengirim JSON).
  app.use(express.json({ limit: '1mb' }));

  app.use('/health', healthRouter);
  app.use('/auth', authRouter);
  app.use('/sync', syncRouter);

  // Urutan wajib: 404 dulu, error handler di paling akhir.
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
