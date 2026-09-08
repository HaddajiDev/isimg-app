import 'dotenv/config';
import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Latest published app version. The app fetches this and prompts the user to
// update when its own build number is lower. Bump these on each release to match
// the +NN in the app's pubspec.yaml.
app.get('/version', (_req, res) =>
  res.json({
    version: '1.4.0',
    build: 23,
  }),
);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`isimg-backend listening on :${PORT}`));
