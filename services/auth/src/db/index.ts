import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

export const query = (text: string, params?: any[]) => pool.query(text, params);

export const initDB = async () => {
    let retries = 5;
    while (retries) {
        try {
            const schemaPath = path.join(__dirname, '../db/schema.sql');
            const schemaSql = fs.readFileSync(schemaPath, 'utf8');
            await pool.query(schemaSql);
            console.log('Database initialized successfully');
            break;
        } catch (err) {
            console.error(`Error initializing database (retries left: ${retries})`, err);
            retries -= 1;
            await new Promise(res => setTimeout(res, 5000));
        }
    }
};
