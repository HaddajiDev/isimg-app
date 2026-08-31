import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/isimg/svc5_crypto.dart';

void main() {
  const vectors = [
    ('hello world', 'gbh4KdOxMhda7I5l', '1cnoSoYrMSDBZRodObMNyw=='),
    ('{"id":"20177418"}', '779889b2abcdef', 'XWe6Y8ibO4NrS7dZs6wkpMFQpvj/CjFVsv0LKagWuaM='),
    ('éàç unicode ✓', 'key123', 'wRNjfa9NiIXeZGCt1QsdRGJy2cXONPx0LOpiOzlcKW4='),
  ];

  group('Svc5Crypto', () {
    test('encrypt matches the server-compatible reference ciphertext', () {
      for (final (plain, pw, cipher) in vectors) {
        expect(Svc5Crypto.encrypt(plain, pw), cipher, reason: plain);
      }
    });

    test('decrypt reverses the reference ciphertext', () {
      for (final (plain, pw, cipher) in vectors) {
        expect(Svc5Crypto.tryDecrypt(cipher, pw), plain, reason: cipher);
      }
    });

    test('decrypt tolerates the leading tabs the API prefixes', () {
      final (plain, pw, cipher) = vectors.first;
      expect(Svc5Crypto.tryDecrypt('\t\t\t\t$cipher', pw), plain);
    });

    test('round-trips arbitrary content', () {
      const pw = 'utoken-abcdef0123456789';
      const plain = '[{"jour":1,"seance":"5","texte":"Cours Probabilité @A6"}]';
      expect(Svc5Crypto.tryDecrypt(Svc5Crypto.encrypt(plain, pw), pw), plain);
    });

    test('returns null on a non-cipher / wrong-key body instead of throwing', () {
      expect(Svc5Crypto.tryDecrypt('', 'k'), isNull);
      expect(Svc5Crypto.tryDecrypt('not base64 %%%', 'k'), isNull);

      expect(Svc5Crypto.tryDecrypt(vectors.first.$3, 'wrong-key'), isNull);
    });
  });
}
