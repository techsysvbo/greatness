#!/usr/bin/env bash
set -e

echo "🚀 Bootstrapping profile system..."

# -----------------------------
# Directories
# -----------------------------
mkdir -p db/migrations
mkdir -p src/db
mkdir -p src/controllers
mkdir -p src/routes
mkdir -p src/middleware
mkdir -p src/components
mkdir -p src/pages

# -----------------------------
# DB Migration
# -----------------------------
cat > db/migrations/001_add_profile_fields.sql <<'SQL'
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS display_name VARCHAR(150),
ADD COLUMN IF NOT EXISTS profession VARCHAR(255),
ADD COLUMN IF NOT EXISTS country_code CHAR(2),
ADD COLUMN IF NOT EXISTS state VARCHAR(150),
ADD COLUMN IF NOT EXISTS city VARCHAR(150);
SQL

# -----------------------------
# DB Pool
# -----------------------------
cat > src/db/index.ts <<'TS'
import { Pool } from "pg";

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  port: parseInt(process.env.POSTGRES_PORT || "5432"),
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});

export default pool;
TS

# -----------------------------
# Migration Runner
# -----------------------------
cat > src/db/migrate.ts <<'TS'
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
TS

# -----------------------------
# Auth Middleware
# -----------------------------
cat > src/middleware/auth.ts <<'TS'
import { Request, Response, NextFunction } from "express";

export function requireAuth(req: any, res: Response, next: NextFunction) {
  if (!req.user || !req.user.id) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  next();
}
TS

# -----------------------------
# Profile Controller
# -----------------------------
cat > src/controllers/profileController.ts <<'TS'
import { Request, Response } from "express";
import pool from "../db";

export async function getProfile(req: any, res: Response) {
  try {
    const userId = req.user.id;

    const result = await pool.query(
      `SELECT user_id, display_name, profession, country_code, state, city, bio, interests
       FROM profiles WHERE user_id = $1`,
      [userId]
    );

    if (!result.rows.length) {
      return res.status(404).json({ error: "Profile not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch profile" });
  }
}

export async function updateProfile(req: any, res: Response) {
  try {
    const userId = req.user.id;
    const {
      display_name,
      profession,
      country_code,
      state,
      city,
      bio,
      interests,
    } = req.body;

    if (!country_code || !city) {
      return res.status(400).json({
        error: "Country and city are required",
      });
    }

    const result = await pool.query(
      `
      INSERT INTO profiles (
        user_id, display_name, profession, country_code, state, city, bio, interests, updated_at
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        profession = EXCLUDED.profession,
        country_code = EXCLUDED.country_code,
        state = EXCLUDED.state,
        city = EXCLUDED.city,
        bio = EXCLUDED.bio,
        interests = EXCLUDED.interests,
        updated_at = NOW()
      RETURNING *
      `,
      [
        userId,
        display_name,
        profession,
        country_code,
        state,
        city,
        bio,
        interests,
      ]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update profile" });
  }
}
TS

# -----------------------------
# Profile Routes
# -----------------------------
cat > src/routes/profileRoutes.ts <<'TS'
import express from "express";
import { getProfile, updateProfile } from "../controllers/profileController";
import { requireAuth } from "../middleware/auth";

const router = express.Router();

router.get("/me", requireAuth, getProfile);
router.put("/me", requireAuth, updateProfile);

export default router;
TS

# -----------------------------
# Location Picker (Frontend)
# -----------------------------
cat > src/components/LocationPicker.tsx <<'TSX'
import React, { useEffect, useState } from "react";

export default function LocationPicker({ onChange }) {
  const [countries, setCountries] = useState([]);

  useEffect(() => {
    fetch("https://restcountries.com/v3.1/all")
      .then(res => res.json())
      .then(data =>
        setCountries(
          data.sort((a, b) =>
            a.name.common.localeCompare(b.name.common)
          )
        )
      );
  }, []);

  return (
    <>
      <select name="country_code" onChange={onChange} required>
        <option value="">Select Country</option>
        {countries.map(c => (
          <option key={c.cca2} value={c.cca2}>
            {c.name.common}
          </option>
        ))}
      </select>

      <input name="state" onChange={onChange} placeholder="State" />
      <input name="city" onChange={onChange} placeholder="City" required />
    </>
  );
}
TSX

# -----------------------------
# Profile Page
# -----------------------------
cat > src/pages/Profile.tsx <<'TSX'
import React, { useState } from "react";
import LocationPicker from "../components/LocationPicker";

export default function Profile() {
  const [form, setForm] = useState({});

  function handleChange(e) {
    setForm({ ...form, [e.target.name]: e.target.value });
  }

  async function handleSubmit(e) {
    e.preventDefault();

    const res = await fetch("/api/profile/me", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(form),
    });

    const data = await res.json();

    if (!res.ok) {
      alert(data.error || "Failed to update profile");
      return;
    }

    alert("Profile updated 🎉");
  }

  return (
    <form onSubmit={handleSubmit}>
      <input name="display_name" onChange={handleChange} placeholder="Name" />
      <input name="profession" onChange={handleChange} placeholder="Profession" />
      <LocationPicker onChange={handleChange} />
      <textarea name="bio" onChange={handleChange} placeholder="Bio" />
      <button type="submit">Save</button>
    </form>
  );
}
TSX

# -----------------------------
# Docker Compose Override
# -----------------------------
cat > docker-compose.override.yml <<'YAML'
services:
  profile-service:
    command: sh -c "npm install && npm run build && node dist/server.js"
YAML

echo "✅ Bootstrap complete!"
echo "➡️ Next steps:"
echo "1) chmod +x bootstrap-profile-system.sh"
echo "2) ./bootstrap-profile-system.sh"
echo "3) docker-compose up --build"

