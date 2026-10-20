import { Router } from 'express';

import { getRatesHandler } from '../controllers/rates.controller.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Dipasang di app dengan prefix '/rates' (F-17 — SCR-04, WF-05).
// Semua endpoint selain register/login memerlukan token sesi.
router.get('/', requireAuth, getRatesHandler);

export default router;
