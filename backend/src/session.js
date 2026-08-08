export const SESSION_HEADER = 'x-isimg-session';

export function encodeSession(jarJSON) {
  return Buffer.from(JSON.stringify(jarJSON), 'utf8').toString('base64');
}

export function decodeSession(raw) {
  if (!raw || typeof raw !== 'string') return null;
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64').toString('utf8'));

    return Array.isArray(parsed?.cookies) ? parsed : null;
  } catch {
    return null;
  }
}

export function requireSession(req, res) {
  const session = decodeSession(req.get(SESSION_HEADER));
  if (!session) {
    res.status(401).json({ error: 'no_session' });
    return null;
  }
  return session;
}

export function withSession(data, jarJSON) {
  return { ...data, session: encodeSession(jarJSON) };
}
