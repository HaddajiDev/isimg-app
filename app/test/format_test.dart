import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/format.dart';

void main() {
  group('cleanFiliere', () {
    test('strips the fixed "Nème année" diploma prefix', () {
      expect(
        cleanFiliere('1ère année Licence en Informatique et Multimédia'),
        'Licence en Informatique et Multimédia',
      );
      expect(cleanFiliere('2ème année Mastère de recherche'), 'Mastère de recherche');
      expect(cleanFiliere('3eme année Cycle ingénieur'), 'Cycle ingénieur');
    });

    test('leaves a diploma without the prefix untouched', () {
      expect(
        cleanFiliere('Licence Appliquée en Informatique'),
        'Licence Appliquée en Informatique',
      );
    });

    test('passes null through and never empties the value', () {
      expect(cleanFiliere(null), isNull);
      expect(cleanFiliere('1ère année'), '1ère année');
    });
  });
}
