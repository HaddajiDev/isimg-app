import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/widgets/student_avatar.dart';

void main() {
  test('seeds the avatar with the student name', () {
    final uri = StudentAvatar.avatarUri('Ahmed Haddaji');

    expect(uri.host, 'api.dicebear.com');
    expect(uri.path, '/10.x/critters/svg');
    expect(uri.queryParameters['seed'], 'ahmed haddaji');
    expect(uri.queryParameters['tags'], 'animation');
    expect(
      uri.queryParameters['animationVariant'],
      'fast:1,fastest:1,medium:1,none:1,slow:1,slowest:1',
    );
  });

  test('escapes characters that would break the query string', () {
    // Accents and spaces are common in student names.
    final uri = StudentAvatar.avatarUri('Amélie Le Roux');
    expect(uri.toString(), isNot(contains(' ')));
    expect(uri.queryParameters['seed'], 'amélie le roux');
  });

  test('name word order does not change the avatar', () {
    // The cursus page says "Ahmed Haddaji"; the relevé says "Haddaji Ahmed".
    // Both must resolve to one avatar for the same student.
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
      isNot(StudentAvatar.avatarUri('Sarra Ben Ali').toString()),
    );
  });
}
