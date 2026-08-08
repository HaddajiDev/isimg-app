import { Router } from 'express';
import { fetchCursus, fetchGrades, fetchSchedule } from '../services/isimgClient.js';
import { requireSession, withSession } from '../session.js';

const router = Router();

async function serve(req, res, fetcher) {
  const session = requireSession(req, res);
  if (!session) return;

  const result = await fetcher(session);

  switch (result.status) {
    case 'unauthorized':
      return res.status(401).json({ error: 'session_expired' });
    case 'unexpected_response':
      return res.status(502).json({ error: 'unexpected_upstream_response' });
    case 'ok':
      return res.json(withSession(result.data, result.jar));
    default:
      return res.status(502).json({ error: 'unexpected_upstream_response' });
  }
}

router.get('/grades', (req, res) =>
  serve(req, res, (session) =>
    fetchGrades(session, req.query.au || null, req.query.ss || null)
  )
);

router.get('/schedule', (req, res) =>
  serve(req, res, (session) => fetchSchedule(session, req.query.week || ''))
);

router.get('/profile', (req, res) => serve(req, res, (session) => fetchCursus(session)));

export default router;
