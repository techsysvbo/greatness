import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

export const query = (text: string, params?: any[]) => pool.query(text, params);

export const initDB = async () => {
    try {
        // Run initial schema (create table)
        const schemaPath = path.join(__dirname, '../db/schema.sql');
        const schemaSql = fs.readFileSync(schemaPath, 'utf8');
        await pool.query(schemaSql);

        // Run migrations
        const migrationsDir = path.join(__dirname, '../db/migrations');
        if (fs.existsSync(migrationsDir)) {
            const files = fs.readdirSync(migrationsDir).sort();
            for (const file of files) {
                if (file.endsWith('.sql')) {
                    const migrationSql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
                    await pool.query(migrationSql);
                    console.log(`Executed migration: ${file}`);
                }
            }
        }

        // Force-create columns to ensure schema is correct even if migrations failed or were skipped
        await pool.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country VARCHAR(100);`);
        await pool.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS state VARCHAR(100);`);
        await pool.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100);`);
        await pool.query(`ALTER TABLE profiles ADD COLUMN IF NOT EXISTS zip_code VARCHAR(20);`);

        console.log('Profile DB initialized and migrations run successfully');
    } catch (err) {
        console.error('Error initializing profile DB', err);
    }
};
