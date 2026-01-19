import express from "express";
import { getProfile, updateProfile } from "../controllers/profileController";
import { requireAuth } from "../middleware/auth";

const router = express.Router();

router.get("/me", requireAuth, getProfile);
router.put("/me", requireAuth, updateProfile);

export default router;
