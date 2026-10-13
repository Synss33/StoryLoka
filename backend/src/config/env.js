import 'dotenv/config';

/**
 * Pembaca konfigurasi lingkungan.
 * Nilai rahasia (API key, dsb.) hanya dibaca dari environment / `.env`
 * dan TIDAK PERNAH dicetak ke log atau dikirim ke klien.
 */
export const env = {
  port: Number(process.env.PORT ?? 3000),
  host: process.env.HOST ?? '0.0.0.0',
  nodeEnv: process.env.NODE_ENV ?? 'development',
  // API key Gemini untuk proxy LLM (WF-07). Kosong sampai diisi di `.env`.
  geminiApiKey: process.env.GEMINI_API_KEY ?? '',
  // Kurs (F-17, WF-05): provider publik tanpa API key, TTL cache server,
  // dan mode luring untuk pengujian deterministik (RATES_OFFLINE=1).
  ratesProviderUrl:
    process.env.RATES_PROVIDER_URL ??
    'https://open.er-api.com/v6/latest/IDR',
  ratesTtlMs: Number(process.env.RATES_TTL_MS ?? 6 * 60 * 60 * 1000),
  ratesOffline: process.env.RATES_OFFLINE === '1',
};

/** Nama & versi layanan untuk response `/health`. */
export const serviceInfo = {
  name: 'storyloka-api',
  version: '0.1.0',
};
