import { Pool } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL
});

export const initDB = async () => {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS profiles (
            user_id SERIAL PRIMARY KEY,
            display_name VARCHAR(100),
            bio TEXT,
            location VARCHAR(100),
            zip_code VARCHAR(20),
            profession VARCHAR(100),
            interests TEXT,
            privacy_settings JSONB,
            country VARCHAR(100),
            city VARCHAR(100),
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        );
    `);
};

export default pool;
