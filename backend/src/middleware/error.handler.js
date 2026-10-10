/** 404: rute tidak ditemukan (JSON, bukan halaman HTML). */
export function notFoundHandler(req, res) {
  res.status(404).json({
    error: {
      code: 'NOT_FOUND',
      message: `Rute ${req.method} ${req.originalUrl} tidak ditemukan`,
    },
  });
}

/**
 * Penangan error global. Selalu dipasang paling akhir.
 * Pesan error internal tidak dibocorkan ke klien di produksi.
 */
export function errorHandler(err, req, res, _next) {
  const status = Number(err.status ?? err.statusCode) || 500;
  // Log stack hanya untuk galat server (5xx) saat pengembangan —
  // galat 4xx (duplikat email, input salah) adalah kondisi wajar.
  if (status >= 500 && process.env.NODE_ENV !== 'production') {
    console.error(`[error] ${req.method} ${req.originalUrl}:`, err);
  }
  res.status(status).json({
    error: {
      code: err.code ?? 'INTERNAL_ERROR',
      // Di produksi, pesan 5xx disamarkan agar tidak membocorkan detail.
      message:
        status >= 500 && process.env.NODE_ENV === 'production'
          ? 'Terjadi kesalahan pada server'
          : err.message ?? 'Terjadi kesalahan pada server',
    },
  });
}
