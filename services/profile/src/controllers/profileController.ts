import { Request, Response } from 'express';
import * as db from '../db';
import { AuthRequest } from '../middleware/auth';

export const getProfile = async (req: AuthRequest, res: Response) => {
    const userId = req.user?.userId;

    try {
        const result = await db.query('SELECT * FROM profiles WHERE user_id = $1', [userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Profile not found' });
        }

        res.json(result.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
};

export const updateProfile = async (req: AuthRequest, res: Response) => {
    const userId = req.user?.userId;
    const { bio, location, zipCode, profession, interests, privacySettings, country, city } = req.body;

    try {
        // Upsert profile
        const queryText = `
      INSERT INTO profiles (user_id, bio, location, zip_code, profession, interests, privacy_settings, country, city)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      ON CONFLICT (user_id) 
      DO UPDATE SET 
        bio = EXCLUDED.bio,
        location = EXCLUDED.location,
        zip_code = EXCLUDED.zip_code,
        profession = EXCLUDED.profession,
        interests = EXCLUDED.interests,
        privacy_settings = EXCLUDED.privacy_settings,
        country = EXCLUDED.country,
        city = EXCLUDED.city,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *;
    `;

        const values = [userId, bio, location, zipCode, profession, interests, privacySettings, country, city];
        const result = await db.query(queryText, values);

        res.json(result.rows[0]);
    } catch (err: any) {
        // Self-Healing: Check for missing column error (Postgres code 42703)
        if (err.code === '42703') {
            console.log('Detected missing columns. Attempting self-healing...');
            try {
                await db.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country VARCHAR(100);`);
                await db.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100);`);
                await db.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS zip_code VARCHAR(20);`);

                // Retry the original query
                const values = [userId, bio, location, zipCode, profession, interests, privacySettings, country, city];
                // Re-define queryText if needed, but it's in scope.
                // Note: we need to redefine it if we want to be safe, but scope is fine here.
                const result = await db.query(`
                      INSERT INTO profiles (user_id, bio, location, zip_code, profession, interests, privacy_settings, country, city)
                      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                      ON CONFLICT (user_id) 
                      DO UPDATE SET 
                        bio = EXCLUDED.bio,
                        location = EXCLUDED.location,
                        zip_code = EXCLUDED.zip_code,
                        profession = EXCLUDED.profession,
                        interests = EXCLUDED.interests,
                        privacy_settings = EXCLUDED.privacy_settings,
                        country = EXCLUDED.country,
                        city = EXCLUDED.city,
                        updated_at = CURRENT_TIMESTAMP
                      RETURNING *;
                 `, values);
                return res.json(result.rows[0]);
            } catch (healErr) {
                console.error('Self-healing failed:', healErr);
            }
        }

        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
};
