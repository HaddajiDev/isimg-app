import 'dotenv/config';
import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.get('/version', (_req, res) =>
  res.json({
    version: '1.5.0',
    build: 24,
  }),
);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`isimg-backend listening on :${PORT}`));
