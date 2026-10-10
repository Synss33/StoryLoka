import cors from 'cors';
import express from 'express';

import { errorHandler, notFoundHandler } from './middleware/error.handler.js';
import healthRouter from './routes/health.route.js';

/**
 * Membuat instance aplikasi Express (terpisah dari proses listen agar
 * bisa dipakai unit test tanpa membuka port).
 *
 * Endpoint (WF-01: backend "kosong" tapi tersambung):
 *   GET /health  -> status layanan
 * Endpoint lain (auth, /sync, /feedback, /ai/*, /rates) menyusul di
 * WF-03…WF-07 sesuai `docs/deskripsi_proyek.md` Bagian 5.2.
 */
export function createApp() {
  const app = express();

  app.use(cors());
  // Batas body 1 MB; JSON only (klien Flutter mengirim JSON).
  app.use(express.json({ limit: '1mb' }));

  app.use('/health', healthRouter);

  // Urutan wajib: 404 dulu, error handler di paling akhir.
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
