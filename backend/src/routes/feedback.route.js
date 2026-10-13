import { Router } from 'express';

import { getFeedback, postFeedback } from '../controllers/feedback.controller.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Dipasang di app dengan prefix '/feedback' (F-08 — SCR-10, WF-04).
router.post('/', requireAuth, postFeedback);
router.get('/', requireAuth, getFeedback);

export default router;
