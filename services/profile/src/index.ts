import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import profileRoutes from './routes/profileRoutes';
import { initDB } from './db';

dotenv.config();

const app = express();
const port = Number(process.env.PORT || 4001);

app.use(cors());
app.use(express.json());

app.use((req, _res, next) => {
  console.log(`[REQ] ${req.method} ${req.url} auth=${req.headers.authorization ? "yes" : "no"}`);
  next();
});
app.use('/profile', profileRoutes);


// Health check
app.get("/health", (_req, res) => res.status(200).send("ok"));
app.get('/', (req, res) => {
    res.send('Profile Service is running');
});

app.listen(port, "0.0.0.0", async() => {
    await initDB();
    console.log(`Profile Service running on port ${port}`);
});
