import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import authRouter from './routes/auth.js';
import dataRouter from './routes/data.js';

const app = express();
app.use(cors());

app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/auth', authRouter);
app.use('/', dataRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`isimg-backend listening on :${PORT}`));
