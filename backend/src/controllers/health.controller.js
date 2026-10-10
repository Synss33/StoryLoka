import { env, serviceInfo } from '../config/env.js';

/**
 * GET /health - endpoint kesehatan (dipakai WF-01 untuk memastikan
 * aplikasi Flutter tersambung ke backend).
 */
export function health(_req, res) {
  res.status(200).json({
    status: 'ok',
    service: serviceInfo.name,
    version: serviceInfo.version,
    environment: env.nodeEnv,
    timestamp: new Date().toISOString(),
    // Uptime server dalam detik (berguna untuk memantau proses dev).
    uptimeSeconds: Math.round(process.uptime()),
  });
}
