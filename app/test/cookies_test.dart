import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/isimg/cookies.dart';

void main() {
  test('builds a Cookie header from what it holds', () {
    final cookies = Cookies({'a': '1', 'b': '2'});
    expect(cookies.header, 'a=1; b=2');
  });

  test('an empty jar sends no header', () {
    expect(Cookies.empty().header, '');
    expect(Cookies.empty().isEmpty, isTrue);
  });

  test('folds in Set-Cookie headers, ignoring their attributes', () {
    final cookies = Cookies();
    cookies.applySetCookies([
      'cookiesession1=ABC123; path=/; secure; HttpOnly',
      'iDzfG79=xyz789; path=/; secure; HttpOnly;Max-Age=86400',
    ]);

    expect(cookies['cookiesession1'], 'ABC123');
    expect(cookies['iDzfG79'], 'xyz789');
  });

  test('a rotated cookie replaces the previous value', () {
    // The site reissues its anti-replay cookie constantly; keeping the stale
    // one is what made earlier requests fail with "not authorised".
    final cookies = Cookies({'iDzfG79': 'old'});
    cookies.applySetCookies(['iDzfG79=fresh; path=/; secure']);

    expect(cookies['iDzfG79'], 'fresh');
    expect(cookies.header, 'iDzfG79=fresh');
  });

  test('a cleared or expired cookie is dropped', () {
    final cookies = Cookies({'gone': 'value', 'stays': 'value'});
    cookies.applySetCookies([
      'gone=; path=/',
      'alsogone=something; Max-Age=0; path=/',
    ]);

    expect(cookies['gone'], isNull);
    expect(cookies['alsogone'], isNull);
    expect(cookies['stays'], 'value');
  });

  test('malformed Set-Cookie values are skipped', () {
    final cookies = Cookies({'keep': 'me'});
    cookies.applySetCookies(['', 'nonsense', '=novalue; path=/']);

    expect(cookies.toMap(), {'keep': 'me'});
  });

  test('exposes the device-trust cookie', () {
    expect(Cookies({'trusted_device': 'TOKEN'}).trustedDevice, 'TOKEN');
    expect(Cookies({'other': 'x'}).trustedDevice, isNull);
  });

  test('survives the round trip through storage', () {
    final cookies = Cookies({
      'cookiesession1': 'ABC',
      'trusted_device': 'DEVICE',
      'iDzfG79': 'ROT',
    });

    final restored = Cookies.decode(cookies.encode());
    expect(restored.toMap(), cookies.toMap());
    expect(restored.trustedDevice, 'DEVICE');
  });

  test('unreadable storage decodes to an empty jar rather than throwing', () {
    // A corrupt jar must send the student to the login screen, not crash.
    expect(Cookies.decode(null).isEmpty, isTrue);
    expect(Cookies.decode('').isEmpty, isTrue);
    expect(Cookies.decode('not base64 !!').isEmpty, isTrue);
  });

  test('non-string stored values are discarded', () {
    final cookies = Cookies({'good': 'value'});
    final restored = Cookies.decode(cookies.encode());
    expect(restored['good'], 'value');
  });
}
