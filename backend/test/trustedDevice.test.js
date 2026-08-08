import assert from 'node:assert/strict';
import test from 'node:test';
import { CookieJar } from 'tough-cookie';

import { extractTrustedDevice, seedTrustedDevice } from '../src/services/isimgClient.js';

const BASE = 'https://isimg.rnu.tn/';
const VALUE = '6d3946665177577043386157587551497a6943776f623370795734664b794d54';

test('a seeded device token is sent to the site', async () => {
  const jar = new CookieJar();
  await seedTrustedDevice(jar, VALUE);

  const header = await jar.getCookieString(BASE);
  assert.match(header, new RegExp(`trusted_device=${VALUE}`));
});

test('seeding nothing leaves the jar empty', async () => {
  const jar = new CookieJar();
  await seedTrustedDevice(jar, null);
  assert.equal(await jar.getCookieString(BASE), '');
});

test('the token is not leaked to other hosts', async () => {
  const jar = new CookieJar();
  await seedTrustedDevice(jar, VALUE);

  assert.equal(await jar.getCookieString('https://example.com/'), '');
});

test('a seeded token survives the jar round-tripping through storage', async () => {
  const jar = new CookieJar();
  await seedTrustedDevice(jar, VALUE);

  const restored = CookieJar.fromJSON(JSON.stringify(jar.toJSON()));
  assert.match(await restored.getCookieString(BASE), new RegExp(`trusted_device=${VALUE}`));
});

test('extractTrustedDevice recovers the token from a jar', async () => {
  const jar = new CookieJar();
  await jar.setCookie(`cookiesession1=ABC; Domain=isimg.rnu.tn; Path=/`, BASE);
  await seedTrustedDevice(jar, VALUE);

  assert.equal(extractTrustedDevice(jar.toJSON()), VALUE);
});

test('extractTrustedDevice returns null when the site issued none', async () => {
  const jar = new CookieJar();
  await jar.setCookie(`cookiesession1=ABC; Domain=isimg.rnu.tn; Path=/`, BASE);

  assert.equal(extractTrustedDevice(jar.toJSON()), null);
});

test('extractTrustedDevice tolerates absent or malformed input', () => {
  assert.equal(extractTrustedDevice(null), null);
  assert.equal(extractTrustedDevice({}), null);
  assert.equal(extractTrustedDevice({ cookies: [] }), null);
});

test('the token round-trips login -> storage -> next login', async () => {
  const afterVerify = new CookieJar();
  await afterVerify.setCookie(`cookiesession1=SESSION1; Domain=isimg.rnu.tn; Path=/`, BASE);
  await seedTrustedDevice(afterVerify, VALUE);

  const stored = extractTrustedDevice(afterVerify.toJSON());
  assert.equal(stored, VALUE);

  const nextLogin = new CookieJar();
  await seedTrustedDevice(nextLogin, stored);

  const header = await nextLogin.getCookieString(BASE);
  assert.match(header, new RegExp(`trusted_device=${VALUE}`));
  assert.doesNotMatch(header, /cookiesession1/);
});
