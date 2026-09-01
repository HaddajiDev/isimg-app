// Capture the "Calendrier de l'A.U." (academic-year calendar, GetCalUniv=4)
// and the année-univ metadata (LoadAnneesUniv=2) to build the page against.
//   $env:ISIMG_USER='2024666'; $env:ISIMG_PASS='...'; node capture_calendrier.mjs

import crypto from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const BASE = 'https://isimg.rnu.tn/svc5/';
const SQL_TOKEN = 'fAKs3F5SG4wlaOZkrmHe6JvVDyNqgth2T9CcYE01L7xPXIQnb8pRjdWUMzoBui';
const SALT_CS = 'gbh4KdOxMhda7I5l', SALT_SC = 'HAUlSIp9lMniD9lo';
const VERSION = process.env.ISIMG_VERSION || '12.7';
const USER = process.env.ISIMG_USER, PASS = process.env.ISIMG_PASS;
if (!USER || !PASS) { console.error('Set ISIMG_USER and ISIMG_PASS first.'); process.exit(1); }
const OUT = join(dirname(fileURLToPath(import.meta.url)), 'captures');
mkdirSync(OUT, { recursive: true });

const keyOf = (pw) => crypto.createHash('sha256').update(Buffer.from(pw, 'ascii')).digest();
const enc = (t, pw) => { const c = crypto.createCipheriv('aes-256-cbc', keyOf(pw), Buffer.alloc(16, 0)); return Buffer.concat([c.update(Buffer.from(t, 'utf8')), c.final()]).toString('base64'); };
const dec = (b, pw) => { const d = crypto.createDecipheriv('aes-256-cbc', keyOf(pw), Buffer.alloc(16, 0)); return Buffer.concat([d.update(Buffer.from(b.trim(), 'base64')), d.final()]).toString('utf8'); };
async function post(f, x) { const r = await fetch(BASE + f, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(x).toString() }); return (await r.text()).trim(); }
async function q(name, req, args, tk, id) {
  const raw = await post('api', { id, tk, req: String(req), args: enc(JSON.stringify(args), tk) });
  let r = null; try { r = JSON.parse(dec(raw, tk)); } catch (e) { console.log(`  ${name}: decrypt failed`); return null; }
  writeFileSync(join(OUT, `${name}.json`), JSON.stringify({ req, args, response: r }, null, 2));
  const n = Array.isArray(r) ? r.length : (r ? 1 : 0);
  console.log(`  ${name.padEnd(14)} req=${String(req).padEnd(2)} -> ${Array.isArray(r) ? `array[${r.length}]` + (n ? ' keys=' + Object.keys(r[0]).join(',') : '') : (r ? 'object' : 'none')}`);
  if (Array.isArray(r) && r[0]) console.log('        sample:', JSON.stringify(r[0]));
  return r;
}

const login = JSON.parse(dec(await post('clg', { token: SQL_TOKEN, args: enc(JSON.stringify({ username: USER, password: PASS, version: VERSION, ui: '2' }), SALT_CS) }), SALT_SC));
if (String(login.auth) !== '1') { console.error('auth failed'); process.exit(2); }
const tk = String(login.token), id = String(login.user_id);
const prof = (await q('profile', 9, { id }, tk, id))[0];
const classe_id = String(prof.classe);
const cfg = (await q('config', 1, { instId: '1' }, tk, id))[0];
const au = Number(cfg.annee_univ);
console.log(`\nclasse_id=${classe_id} au=${au}\n`);

console.log('== Calendrier universitaire (GetCalUniv) ==');
await q('calendrier', 4, { user_type: '1', au: String(au), classe_id }, tk, id);
await q('calendrier_prev', 4, { user_type: '1', au: String(au - 1), classe_id }, tk, id);

console.log('\n== Année universitaire (LoadAnneesUniv) ==');
await q('annee_univ', 2, { au: String(au) }, tk, id);
console.log(`\nDone -> ${OUT}`);
