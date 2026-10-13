import { Router } from 'express';

import { sync } from '../controllers/sync.controller.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Dipasang di app dengan prefix '/sync'. Semua endpoint selain
// register/login memerlukan token sesi (Bagian 5.2).
router.post('/', requireAuth, sync);

export default router;
