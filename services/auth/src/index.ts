import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { Pool } from 'pg';

dotenv.config();

import authRoutes from './routes/authRoutes';
import { initDB } from './db';

const app = express();
const port = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

// Routes
app.use('/auth', authRoutes); // Mounted at /auth, so /auth/register will be the path

// Basic health check
app.get("/health", (_req, res) => res.status(200).send("ok"));
app.get('/', (req, res) => {
    res.send('Auth Service is running');
});

app.listen(port, async () => {
    await initDB();
    console.log(`Auth Service running on port ${port}`);
});
