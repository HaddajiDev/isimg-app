import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import multer from 'multer';

const app = express();
app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.get('/version', (_req, res) =>
  res.json({
    version: '1.11.7',
    build: 37,
  }),
);

const FEEDBACK_TYPES = { bug: 'Bug', idea: 'Idée', other: 'Autre' };
const MAX_MESSAGE = 2000;

const RATE_WINDOW_MS = 60 * 60 * 1000;
const RATE_MAX = 5;
const hits = new Map();

function rateLimited(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < RATE_WINDOW_MS);
  if (recent.length >= RATE_MAX) {
    hits.set(ip, recent);
    return true;
  }
  recent.push(now);
  hits.set(ip, recent);
  if (hits.size > 5000) hits.clear();
  return false;
}

const escapeHtml = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const cleanText = (v, max) =>
  typeof v === 'string' ? v.replace(/\u0000/g, '').trim().slice(0, max) : '';

const MAX_IMAGES = 3;
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: MAX_IMAGES, fileSize: 3 * 1024 * 1024, fields: 10, fieldSize: 8 * 1024 },
  fileFilter: (_req, file, cb) => cb(null, /^image\/(jpeg|png|webp)$/.test(file.mimetype)),
});

function feedbackLimit(req, res, next) {
  const ip = (req.headers['x-forwarded-for'] ?? '').toString().split(',')[0].trim() || req.ip;
  if (rateLimited(ip)) return res.status(429).json({ error: 'rate_limited' });
  next();
}

function feedbackUpload(req, res, next) {
  if (!req.is('multipart/form-data')) return next();
  upload.array('images', MAX_IMAGES)(req, res, (err) => {
    if (!err) return next();
    if (err.code === 'LIMIT_FILE_SIZE') return res.status(413).json({ error: 'image_too_large' });
    if (err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({ error: 'too_many_images' });
    }
    return res.status(400).json({ error: 'bad_upload' });
  });
}

async function telegram(token, method, payload) {
  const isForm = payload instanceof FormData;
  const tg = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
    method: 'POST',
    headers: isForm ? undefined : { 'Content-Type': 'application/json' },
    body: isForm ? payload : JSON.stringify(payload),
    signal: AbortSignal.timeout(20000),
  });
  if (!tg.ok) throw new Error(`${method} ${tg.status} ${await tg.text()}`);
}

async function sendPhotos(token, chatId, images, caption) {
  const form = new FormData();
  form.append('chat_id', chatId);
  if (images.length === 1) {
    form.append('photo', new Blob([images[0].buffer], { type: images[0].mimetype }), 'image0.jpg');
    if (caption) {
      form.append('caption', caption);
      form.append('parse_mode', 'HTML');
    }
    return telegram(token, 'sendPhoto', form);
  }
  const media = images.map((img, i) => ({
    type: 'photo',
    media: `attach://image${i}`,
    ...(i === 0 && caption ? { caption, parse_mode: 'HTML' } : {}),
  }));
  form.append('media', JSON.stringify(media));
  images.forEach((img, i) =>
    form.append(`image${i}`, new Blob([img.buffer], { type: img.mimetype }), `image${i}.jpg`),
  );
  return telegram(token, 'sendMediaGroup', form);
}

app.post('/feedback', feedbackLimit, feedbackUpload, async (req, res) => {
  const body = req.body ?? {};
  const images = Array.isArray(req.files) ? req.files : [];
  const message = cleanText(body.message, MAX_MESSAGE);
  if (message.length < 3) return res.status(400).json({ error: 'message_required' });

  const type = Object.hasOwn(FEEDBACK_TYPES, body.type) ? body.type : 'other';
  const ratingValue = Number(body.rating);
  const rating = Number.isInteger(ratingValue) && ratingValue >= 1 && ratingValue <= 5 ? ratingValue : null;
  const contact = cleanText(body.contact, 100);
  const appVersion = cleanText(body.appVersion, 30);
  const device = cleanText(body.device, 80);

  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) return res.status(503).json({ error: 'not_configured' });

  const header = [
    `<b>${FEEDBACK_TYPES[type]}</b>`,
    rating ? `${rating}/5` : null,
    appVersion ? `v${escapeHtml(appVersion)}` : null,
    images.length ? `${images.length} image${images.length > 1 ? 's' : ''}` : null,
  ]
    .filter(Boolean)
    .join(' · ');
  const text = [
    header,
    '',
    escapeHtml(message),
    contact ? `\nContact : ${escapeHtml(contact)}` : null,
    device ? `<i>${escapeHtml(device)}</i>` : null,
  ]
    .filter((l) => l !== null)
    .join('\n');

  try {
    if (images.length === 0) {
      await telegram(token, 'sendMessage', {
        chat_id: chatId,
        text,
        parse_mode: 'HTML',
        disable_web_page_preview: true,
      });
    } else if (text.length <= 1024) {
      await sendPhotos(token, chatId, images, text);
    } else {
      await telegram(token, 'sendMessage', {
        chat_id: chatId,
        text,
        parse_mode: 'HTML',
        disable_web_page_preview: true,
      });
      await sendPhotos(token, chatId, images, null);
    }
    return res.json({ ok: true });
  } catch (e) {
    console.error('telegram delivery failed', e);
    return res.status(502).json({ error: 'delivery_failed' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`isimg-backend listening on :${PORT}`));
