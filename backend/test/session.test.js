import assert from 'node:assert/strict';
import test from 'node:test';
import { CookieJar } from 'tough-cookie';

import { decodeSession, encodeSession, withSession } from '../src/session.js';

const BASE = 'https://isimg.rnu.tn/';

async function sampleJar() {
  const jar = new CookieJar();
  await jar.setCookie('cookiesession1=ABC123; Domain=isimg.rnu.tn; Path=/', BASE);
  await jar.setCookie('trusted_device=DEVICE1; Domain=isimg.rnu.tn; Path=/', BASE);
  return jar;
}

test('a jar survives the round trip to the device and back', async () => {
  const jar = await sampleJar();

  const restored = CookieJar.fromJSON(JSON.stringify(decodeSession(encodeSession(jar.toJSON()))));

  const header = await restored.getCookieString(BASE);
  assert.match(header, /cookiesession1=ABC123/);
  assert.match(header, /trusted_device=DEVICE1/);
});

test('decodeSession rejects anything that is not a jar', () => {
  assert.equal(decodeSession(null), null);
  assert.equal(decodeSession(''), null);
  assert.equal(decodeSession('not-base64-at-all!!'), null);

  assert.equal(decodeSession(Buffer.from('{"a":1}').toString('base64')), null);
  assert.equal(decodeSession(Buffer.from('[]').toString('base64')), null);
});

test('withSession returns the payload alongside the refreshed session', async () => {
  const jar = await sampleJar();
  const body = withSession({ moyenneGenerale: '11.13' }, jar.toJSON());

  assert.equal(body.moyenneGenerale, '11.13');
  assert.ok(body.session, 'the device needs the updated session back');
  assert.deepEqual(decodeSession(body.session).cookies.length, 2);
});

test('a rotated cookie is what the device gets back, not the original', async () => {
  const jar = await sampleJar();

  await jar.setCookie('cookiesession1=ROTATED; Domain=isimg.rnu.tn; Path=/', BASE);

  const restored = CookieJar.fromJSON(
    JSON.stringify(decodeSession(withSession({}, jar.toJSON()).session))
  );

  const header = await restored.getCookieString(BASE);
  assert.match(header, /cookiesession1=ROTATED/);
  assert.doesNotMatch(header, /ABC123/);
});

test('the encoded session carries no plaintext credentials', async () => {
  const jar = await sampleJar();
  const decoded = Buffer.from(encodeSession(jar.toJSON()), 'base64').toString('utf8');

  assert.doesNotMatch(decoded, /password/i);
});
