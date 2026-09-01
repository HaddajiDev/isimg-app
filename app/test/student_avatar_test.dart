import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/widgets/student_avatar.dart';

void main() {
  test('seeds the avatar with the student name', () {
    final uri = StudentAvatar.avatarUri('Ahmed Haddaji');

    expect(uri.host, 'api.dicebear.com');
    expect(uri.path, '/10.x/critters/png');
    expect(uri.queryParameters['seed'], 'ahmed haddaji');
  });

  test('requests a raster PNG so every renderer paints it identically', () {
    final uri = StudentAvatar.avatarUri('Ahmed Haddaji');

    expect(uri.path, endsWith('/png'));
    expect(uri.queryParameters['size'], '160');
    expect(uri.toString(), isNot(contains('animationVariant')));
    expect(uri.toString(), isNot(contains('tags')));
  });

  test('escapes characters that would break the query string', () {
    final uri = StudentAvatar.avatarUri('Amélie Le Roux');
    expect(uri.toString(), isNot(contains(' ')));
    expect(uri.queryParameters['seed'], 'amélie le roux');
  });

  test('name word order does not change the avatar', () {
    expect(
      StudentAvatar.avatarUri('Ahmed Haddaji').toString(),
      StudentAvatar.avatarUri('Haddaji Ahmed').toString(),
    );
    expect(
      StudentAvatar.avatarUri('  ahmed   HADDAJI ').toString(),
      StudentAvatar.avatarUri('Haddaji Ahmed').toString(),
    );
  });

  test('same name yields a stable url, different names differ', () {
    expect(
      StudentAvatar.avatarUri('Ahmed Haddaji').toString(),
      StudentAvatar.avatarUri('Ahmed Haddaji').toString(),
    );
    expect(
      StudentAvatar.avatarUri('Ahmed Haddaji').toString(),
      isNot(StudentAvatar.avatarUri('Imed eddine Amara').toString()),
    );
  });

  test('canonicalises the seed for a three-part name', () {
    expect(StudentAvatar.canonicalSeed('Imed eddine Amara'), 'amara eddine imed');
  });
}
