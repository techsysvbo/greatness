import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import profileRoutes from './routes/profileRoutes';
import { initDB } from './db';

dotenv.config();

const app = express();
const port = process.env.PORT || 4001;

app.use(cors());
app.use(express.json());
app.use('/profile', profileRoutes);

app.get('/', (req, res) => {
    res.send('Profile Service is running');
});

app.listen(port, async () => {
    await initDB();
    console.log(`Profile Service running on port ${port}`);
});
