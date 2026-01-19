import fs from "fs";
import path from "path";
import pool from "./index";

export async function runMigrations() {
  const migrationsDir = path.join(process.cwd(), "db/migrations");
  const files = fs.readdirSync(migrationsDir).sort();

  console.log("📦 Running migrations:", files);

  for (const file of files) {
    const sql = fs.readFileSync(path.join(migrationsDir, file), "utf8");
    await pool.query(sql);
    console.log(`✅ Applied ${file}`);
  }
}
