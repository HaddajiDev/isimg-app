import { Router } from 'express';
import { loginToIsimg, verifyOtp } from '../services/isimgClient.js';
import { decodeSession, encodeSession, withSession } from '../session.js';

const router = Router();

router.post('/login', async (req, res) => {
  const { username, password, trustedDevice } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: 'missing_credentials' });
  }

  const result = await loginToIsimg(username, password, trustedDevice ?? null);

  if (result.status === 'failed') {
    return res.status(401).json({ error: 'login_failed', reason: result.reason });
  }

  if (result.status === '2fa_required') {
    return res.json({
      status: '2fa_required',
      session: encodeSession(result.jar),
      token2fa: result.token2fa,
    });
  }

  res.json(withSession({ status: 'ok' }, result.jar));
});

router.post('/verify-otp', async (req, res) => {
  const { session, token2fa, code } = req.body || {};
  if (!session || !token2fa || !code) {
    return res.status(400).json({ error: 'missing_fields' });
  }

  const jar = decodeSession(session);
  if (!jar) return res.status(400).json({ error: 'invalid_session' });

  const result = await verifyOtp(jar, token2fa, code);
  if (result.status !== 'ok') {
    return res.status(401).json({ error: 'invalid_otp' });
  }

  res.json(withSession({ status: 'ok' }, result.jar));
});

export default router;
