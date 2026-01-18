import { Router } from 'express';
import { getProfile, updateProfile } from '../controllers/profileController';
import { authenticate } from '../middleware/auth';

const router = Router();

router.get('/me', authenticate, getProfile);
router.put('/me', authenticate, updateProfile);

export default router;
