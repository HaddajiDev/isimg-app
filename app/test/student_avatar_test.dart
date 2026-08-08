import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/widgets/student_avatar.dart';

void main() {
  test('seeds the avatar with the student name', () {
    final uri = StudentAvatar.avatarUri('Ahmed Haddaji');

    expect(uri.host, 'api.dicebear.com');
    expect(uri.path, '/10.x/critters/svg');
    expect(uri.queryParameters['seed'], 'ahmed haddaji');
  });

  test('sends nothing but the seed', () {
    // animationVariant/tags were dropped: flutter_svg cannot animate, and some
    // encodings of them made the API answer 400, which the old network loader
    // then fed to the SVG parser as if it were an image.
    final uri = StudentAvatar.avatarUri('Ahmed Haddaji');

    expect(uri.queryParameters.keys, ['seed']);
    expect(uri.toString(), isNot(contains('animationVariant')));
    expect(uri.toString(), isNot(contains('tags')));
  });

  test('escapes characters that would break the query string', () {
    final uri = StudentAvatar.avatarUri('Amélie Le Roux');
    expect(uri.toString(), isNot(contains(' ')));
    expect(uri.queryParameters['seed'], 'amélie le roux');
  });

  test('name word order does not change the avatar', () {
    // The cursus page says "Ahmed Haddaji"; the relevé says "Haddaji Ahmed".
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
    // The account this first failed on.
    expect(StudentAvatar.canonicalSeed('Imed eddine Amara'), 'amara eddine imed');
  });
}
