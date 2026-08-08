import axios from 'axios';
import { wrapper } from 'axios-cookiejar-support';
import { CookieJar } from 'tough-cookie';
import * as cheerio from 'cheerio';

const BASE = 'https://isimg.rnu.tn';
const HOME_URL = `${BASE}/fra/home`;
const CHECK_ACCOUNT_URL = `${BASE}/fra/intranet/check_account`;
const VERIFY_2FA_URL = `${BASE}/fra/intranet/verify_2fa`;
const RDN_URL = `${BASE}/fra/intranet/etudiant/rdn`;
const EMPLOI_URL = `${BASE}/fra/intranet/etudiant/emploi`;

const CURSUS_URL = `${BASE}/fra/intranet/etu/moncursus`;

const TRUSTED_DEVICE_COOKIE = 'trusted_device';

const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0',
  Accept:
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  'Accept-Language': 'en-GB,en;q=0.9,en-US;q=0.8',
};

const FORM_HEADERS = {
  ...HEADERS,
  'Content-Type': 'application/x-www-form-urlencoded',
  Origin: 'null',
};

function newClient(jarJSON) {
  const jar = jarJSON ? CookieJar.fromJSON(JSON.stringify(jarJSON)) : new CookieJar();
  const client = wrapper(axios.create({ jar, headers: HEADERS, validateStatus: () => true }));
  return { client, jar };
}

function extractInputValue(html, name) {
  const re = new RegExp(`name=["']${name}["']\\s+value=["']([^"']+)["']`, 'i');
  const m = html.match(re);
  return m ? m[1] : null;
}

function extractMetaRefresh(html) {
  const m = html.match(/<meta[^>]+http-equiv=["']refresh["'][^>]+content=["'][^;]+;\s*URL=([^"'>\s]+)["']?/i);
  return m ? m[1] : null;
}

function isUnauthorized(html) {
  return html.includes("Vous n'êtes pas autorisé");
}

export async function loginToIsimg(username, password, trustedDevice = null) {
  const { client, jar } = newClient();

  await seedTrustedDevice(jar, trustedDevice);

  const homeRes = await client.get(HOME_URL);
  const token = extractInputValue(homeRes.data, 'token');
  if (!token) return { status: 'failed', reason: 'login_token_not_found' };

  const loginRes = await client.post(
    CHECK_ACCOUNT_URL,
    new URLSearchParams({ token, username, password }).toString(),
    { headers: FORM_HEADERS }
  );

  const redirectUrl = extractMetaRefresh(loginRes.data);
  if (!redirectUrl) return { status: 'failed', reason: 'invalid_credentials' };

  if (redirectUrl.includes('verify_2fa')) {
    const otpRes = await client.get(new URL(redirectUrl, BASE).toString());
    const token2fa = extractInputValue(otpRes.data, 'token2fa');
    if (!token2fa) return { status: 'failed', reason: 'otp_token_not_found' };
    return { status: '2fa_required', jar: jar.toJSON(), token2fa };
  }

  return { status: 'ok', jar: jar.toJSON() };
}

export async function seedTrustedDevice(jar, trustedDevice) {
  if (!trustedDevice) return;
  await jar.setCookie(
    `${TRUSTED_DEVICE_COOKIE}=${trustedDevice}; Domain=isimg.rnu.tn; Path=/; Secure`,
    `${BASE}/`
  );
}

export function extractTrustedDevice(jarJSON) {
  const cookies = jarJSON?.cookies ?? [];
  return cookies.find((cookie) => cookie.key === TRUSTED_DEVICE_COOKIE)?.value ?? null;
}

export async function verifyOtp(jarJSON, token2fa, code) {
  const { client, jar } = newClient(jarJSON);

  const res = await client.post(
    VERIFY_2FA_URL,
    new URLSearchParams({ token2fa, code, remember_device: 'on' }).toString(),
    { headers: FORM_HEADERS }
  );

  const redirectUrl = extractMetaRefresh(res.data);
  if (redirectUrl && !redirectUrl.includes('verify_2fa')) {
    return { status: 'ok', jar: jar.toJSON() };
  }
  return { status: 'failed', reason: 'invalid_or_expired_code' };
}

export async function fetchGrades(jarJSON, auCode, ssCode) {
  const { client, jar } = newClient(jarJSON);

  const load = async (au, ss) => {
    const res = await client.post(
      RDN_URL,
      new URLSearchParams({ f_au: au, f_ss: ss }).toString(),
      { headers: FORM_HEADERS }
    );
    return res.data;
  };

  const probe = await client.get(RDN_URL);
  if (isUnauthorized(probe.data)) {
    return { status: 'unauthorized' };
  }

  const $probe = cheerio.load(probe.data);
  const annees = parseSelectOptions($probe, 'f_au');
  const sessions = parseSelectOptions($probe, 'f_ss');

  const ss = ssCode ?? pickSelected(sessions) ?? '1';
  let au = auCode ?? pickSelected(annees);
  let html;

  if (au) {
    html = await load(au, ss);
  } else {
    for (const option of annees) {
      const candidate = await load(option.code, ss);
      if (isUnauthorized(candidate)) return { status: 'unauthorized' };
      const isFirst = html === undefined;
      const published = parseGrades(candidate).moyenneGenerale != null;
      if (published || isFirst) {
        au = option.code;
        html = candidate;
      }
      if (published) break;
    }
  }

  if (!html || isUnauthorized(html)) {
    return { status: html ? 'unauthorized' : 'unexpected_response' };
  }

  return {
    status: 'ok',
    data: { ...parseGrades(html), currentAu: au, currentSs: ss },
    jar: jar.toJSON(),
  };
}

function pickSelected(options) {
  return options.find((o) => o.selected)?.code;
}

export async function fetchCursus(jarJSON) {
  const { client, jar } = newClient(jarJSON);

  const res = await client.get(CURSUS_URL);

  if (isUnauthorized(res.data)) {
    return { status: 'unauthorized' };
  }

  if (!res.data.includes('<title>ISIMG - Cursus</title>')) {
    return { status: 'unexpected_response' };
  }

  return { status: 'ok', data: parseCursus(res.data), jar: jar.toJSON() };
}

function parseCursus(html) {
  const $ = cheerio.load(html);
  const content = $('#content');

  const field = (label) => {
    let value = null;
    content.find('p.text-slate-500').each((_, el) => {
      const labelEl = $(el);
      if (labelEl.text().replace(/\s+/g, ' ').trim() !== label) return;
      const whole = labelEl.parent().text().replace(/\s+/g, ' ').trim();
      value = whole.slice(label.length).trim() || null;
      return false;
    });
    return value;
  };

  const table = content.find('table').first();
  const headers = table
    .find('tr')
    .first()
    .children('th,td')
    .map((_, cell) => $(cell).text().replace(/\s+/g, ' ').trim())
    .get();

  const years = table
    .find('tr')
    .slice(1)
    .map((_, tr) => {
      const cells = $(tr)
        .children('td,th')
        .map((__, cell) => $(cell).text().replace(/\s+/g, ' ').trim())
        .get();
      if (cells.length === 0) return null;
      const row = {};
      headers.forEach((header, i) => {
        row[header] = cells[i] ?? null;
      });
      return row;
    })
    .get()
    .filter(Boolean);

  return {
    prenom: field('Prénom'),
    nom: field('Nom'),
    cin: field('CIN'),
    filiere: content.find('h2').first().text().replace(/\s+/g, ' ').trim() || null,
    years,
  };
}

export async function fetchSchedule(jarJSON, week) {
  const { client, jar } = newClient(jarJSON);

  const url = week ? `${EMPLOI_URL}/${week}/0` : EMPLOI_URL;

  const res = await client.get(url);

  if (isUnauthorized(res.data)) {
    return { status: 'unauthorized' };
  }

  if (!res.data.includes('id="desktop-view"')) {
    return { status: 'unexpected_response' };
  }

  return { status: 'ok', data: parseSchedule(res.data), jar: jar.toJSON() };
}

function tableToGrid($, tableEl) {
  const grid = [];
  $(tableEl)
    .find('tr')
    .each((rowIndex, tr) => {
      if (!grid[rowIndex]) grid[rowIndex] = [];
      let colIndex = 0;
      $(tr)
        .children('td,th')
        .each((_, cellEl) => {
          while (grid[rowIndex][colIndex] !== undefined) colIndex++;
          const cell = $(cellEl);
          const rowspan = parseInt(cell.attr('rowspan') || '1', 10);
          const colspan = parseInt(cell.attr('colspan') || '1', 10);
          cell.find('br').replaceWith(' ');
          const text = cell.text().replace(/\s+/g, ' ').trim();
          for (let r = 0; r < rowspan; r++) {
            if (!grid[rowIndex + r]) grid[rowIndex + r] = [];
            for (let c = 0; c < colspan; c++) {
              grid[rowIndex + r][colIndex + c] = text;
            }
          }
          colIndex += colspan;
        });
    });
  return grid.filter((row) => row && row.length);
}

function parseGrades(html) {
  const $ = cheerio.load(html);
  const contentText = $('#content').text();

  const field = (label) => {
    const re = new RegExp(`${label}\\s*:\\s*([^\\n]+)`, 'i');
    const m = contentText.match(re);
    return m ? m[1].trim() : null;
  };

  return {
    nom: field('Nom Prénom'),
    cin: field('CIN \\(code\\)'),
    filiere: field('Filière'),
    niveau: field('Niveau'),
    moyenneGenerale: field('Moyenne générale'),
    credits: field('Crédits'),
    rang: field('Rang'),
    semesters: parseGradeTree($),
    annees: parseSelectOptions($, 'f_au'),
    sessions: parseSelectOptions($, 'f_ss'),
  };
}

function firstNumber(text) {
  const match = String(text ?? '').match(/-?\d+(?:[.,]\d+)?/);
  return match ? parseFloat(match[0].replace(',', '.')) : null;
}

function parseGradeTree($) {
  const table = $('#large table.mytable').first();
  if (!table.length) return [];

  const [header, ...rows] = tableToGrid($, table);
  if (!header) return [];

  const col = (name) => header.indexOf(name);
  const idx = {
    sem: col('Sem.'),
    unite: col('Unité'),
    coefUnite: col('Coef. Unité'),
    matiere: col('Matière'),
    regime: col('Régime'),
    coefMatiere: col('Coeff'),
    credits: col('Crédits'),
    epreuve: col('Epreuve'),
    note: col('Note'),
    moyMatiere: col('Moy. Mat.'),
    moyUnite: col('Moy. Unité.'),
  };

  const semesters = new Map();

  for (const row of rows) {
    const cell = (i) => (i >= 0 ? (row[i] ?? '') : '');

    const semLabel = cell(idx.sem).trim();
    const uniteLabel = cell(idx.unite).trim();
    const matiereLabel = cell(idx.matiere).trim();
    if (!semLabel && !uniteLabel && !matiereLabel) continue;

    if (!semesters.has(semLabel)) {
      semesters.set(semLabel, { semestre: semLabel, unites: new Map() });
    }
    const unites = semesters.get(semLabel).unites;

    if (!unites.has(uniteLabel)) {
      unites.set(uniteLabel, {
        libelle: uniteLabel.replace(/\s*Crédits\s*=.*$/i, '').trim() || uniteLabel,
        coefficient: firstNumber(cell(idx.coefUnite)),
        credits: firstNumber((uniteLabel.match(/Crédits\s*=\s*([\d.,]+)/i) ?? [])[1]),
        moyenne: firstNumber(cell(idx.moyUnite)),
        matieres: new Map(),
      });
    }
    const matieres = unites.get(uniteLabel).matieres;

    if (!matieres.has(matiereLabel)) {
      matieres.set(matiereLabel, {
        libelle: matiereLabel,
        regime: cell(idx.regime).trim() || null,
        coefficient: firstNumber(cell(idx.coefMatiere)),
        credits: firstNumber(cell(idx.credits)),
        moyenne: firstNumber(cell(idx.moyMatiere)),
        epreuves: [],
      });
    }

    const epreuveLabel = cell(idx.epreuve).trim();
    if (epreuveLabel) {
      const noteCell = cell(idx.note).trim();
      matieres.get(matiereLabel).epreuves.push({
        libelle: epreuveLabel,

        poids: firstNumber((epreuveLabel.match(/\(([^)]+)\)/) ?? [])[1]),
        note: firstNumber(noteCell),

        absent: /^abs/i.test(noteCell),
      });
    }
  }

  return [...semesters.values()].map((sem) => ({
    semestre: sem.semestre,
    unites: [...sem.unites.values()].map((unite) => ({
      ...unite,
      matieres: [...unite.matieres.values()],
    })),
  }));
}

function parseSelectOptions($, selectName) {
  return $(`select[name="${selectName}"] option`)
    .map((_, el) => {
      const option = $(el);
      const code = option.attr('value');
      if (!code) return null;
      return {
        code,
        label: option.text().trim(),
        selected: option.attr('selected') != null,
      };
    })
    .get()
    .filter(Boolean);
}

function parseSchedule(html) {
  const $ = cheerio.load(html);
  const weekLabelMatch = html.match(/(\d{2}\s*→\s*\d{2}\s+\p{L}+\s+\d{4})/u);
  const noSessions = html.includes("Aucune séance") || html.includes('Aucun cours cette semaine');

  return {
    weekLabel: weekLabelMatch ? weekLabelMatch[1] : null,
    hasSessions: !noSessions,

    rawContentHtml: $('#desktop-view').html() || null,
  };
}
