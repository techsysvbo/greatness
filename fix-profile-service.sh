#!/bin/bash
set -e

echo "=== Step 1: Writing fixed TypeScript files ==="

# profileController.ts
cat > services/profile/src/controllers/profileController.ts << 'EOF'
import { Request, Response } from 'express';
import pool from '../db';
import { AuthRequest } from '../middleware/authMiddleware';

export const getProfile = async (req: AuthRequest, res: Response) => {
    const userId = req.user?.id;

    try {
        const result = await pool.query('SELECT * FROM profiles WHERE user_id = $1', [userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Profile not found' });
        }

        res.json(result.rows[0]);
    } catch (err) {
        console.error('GET PROFILE ERROR:', err);
        res.status(500).json({ message: 'Server error' });
    }
};

export const updateProfile = async (req: AuthRequest, res: Response) => {
    const userId = req.user?.id;
    const {
        bio,
        location,
        zip_code,
        profession,
        interests,
        privacy_settings,
        country,
        city,
        display_name
    } = req.body;

    try {
        const queryText = `
            INSERT INTO profiles (
                user_id, display_name, bio, location, zip_code, profession,
                interests, privacy_settings, country, city, updated_at
            )
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW())
            ON CONFLICT (user_id) DO UPDATE SET
                display_name = EXCLUDED.display_name,
                bio = EXCLUDED.bio,
                location = EXCLUDED.location,
                zip_code = EXCLUDED.zip_code,
                profession = EXCLUDED.profession,
                interests = EXCLUDED.interests,
                privacy_settings = EXCLUDED.privacy_settings,
                country = EXCLUDED.country,
                city = EXCLUDED.city,
                updated_at = NOW()
            RETURNING *;
        `;

        const values = [
            userId,
            display_name || null,
            bio || null,
            location || null,
            zip_code || null,
            profession || null,
            interests || null,
            privacy_settings || null,
            country || null,
            city || null
        ];

        const result = await pool.query(queryText, values);
        res.json(result.rows[0]);
    } catch (err) {
        console.error('UPDATE PROFILE ERROR:', err);
        res.status(500).json({ message: 'Failed to update profile', detail: (err as Error).message });
    }
};
EOF

# profileRoutes.ts
cat > services/profile/src/routes/profileRoutes.ts << 'EOF'
import { Router } from 'express';
import { getProfile, updateProfile } from '../controllers/profileController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

router.get('/me', authMiddleware, getProfile);
router.put('/me', authMiddleware, updateProfile);

export default router;
EOF

echo "=== Step 2: Ensuring profiles table exists ==="
sleep 5

docker exec -i ag-workspace-db-1 psql -U admin -d diaspora_db << 'EOSQL'
CREATE TABLE IF NOT EXISTS profiles (
    user_id SERIAL PRIMARY KEY,
    display_name VARCHAR(255),
    bio TEXT,
    location VARCHAR(255),
    zip_code VARCHAR(20),
    profession VARCHAR(255),
    interests TEXT,
    privacy_settings JSONB,
    country VARCHAR(100),
    city VARCHAR(100),
    updated_at TIMESTAMP DEFAULT NOW()
);
EOSQL

echo "=== Step 3: Rebuilding profile-service Docker image ==="
docker-compose build --no-cache profile-service

echo "=== Step 4: Starting profile-service container ==="
docker-compose up -d profile-service

echo "✅ Profile service fixed and running!"
