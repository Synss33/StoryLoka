import { Router } from 'express';

import { health } from '../controllers/health.controller.js';

const router = Router();

// Dipasang di app dengan prefix '/health' → GET /health
router.get('/', health);

export default router;
