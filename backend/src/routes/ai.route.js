import { Router } from 'express';

import {
  chatHandler,
  recommendHandler,
  summarizeHandler,
} from '../controllers/ai.controller.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Dipasang di app dengan prefix '/ai' (F-11 — SCR-05/06, WF-07).
// Semua endpoint memerlukan token sesi; API key Gemini tetap di server.
router.post('/chat', requireAuth, chatHandler);
router.post('/summarize', requireAuth, summarizeHandler);
router.post('/recommend', requireAuth, recommendHandler);

export default router;
