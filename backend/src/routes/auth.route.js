import { Router } from 'express';

import { login, logout, register } from '../controllers/auth.controller.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Dipasang di app dengan prefix '/auth'.
router.post('/register', register);
router.post('/login', login);
// Logout memerlukan token sesi (Bagian 5.2: endpoint selain register/login).
router.post('/logout', requireAuth, logout);

export default router;
