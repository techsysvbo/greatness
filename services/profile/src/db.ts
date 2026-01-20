import { Pool } from "pg";
import dotenv from "dotenv";
dotenv.config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function sleep(ms: number) {
  await new Promise((r) => setTimeout(r, ms));
}

export async function initDB() {
  const maxAttempts = 30;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await pool.query("SELECT 1;");
      break;
    } catch (err) {
      console.log(`DB not ready (attempt ${attempt}/${maxAttempts})...`);
      await sleep(1000);
    }
  }

  // Create table if missing
  await pool.query(`
    CREATE TABLE IF NOT EXISTS profiles (
      user_id INTEGER PRIMARY KEY,
      display_name VARCHAR(255),
      bio TEXT,
      location VARCHAR(255),
      zip_code VARCHAR(20),
      profession VARCHAR(255),
      interests TEXT,
      privacy_settings JSONB,
      country VARCHAR(100),
      state VARCHAR(100),
      city VARCHAR(100),
      updated_at TIMESTAMP DEFAULT NOW()
    );
  `);
}

export default pool;
