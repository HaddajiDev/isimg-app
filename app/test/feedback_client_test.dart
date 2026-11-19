import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isimg_app/core/feedback_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('posts the message, type, rating and contact as JSON', () async {
    late Map<String, dynamic> sent;
    final client = FeedbackClient(
      httpClient: MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/feedback');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await client.send(
      message: '  Le nouvel emploi est top  ',
      type: FeedbackType.idea,
      rating: 5,
      contact: ' @etudiant ',
    );

    expect(sent['message'], 'Le nouvel emploi est top');
    expect(sent['type'], 'idea');
    expect(sent['rating'], 5);
    expect(sent['contact'], '@etudiant');
    expect(sent.containsKey('device'), isTrue);
  });

  test('omits an empty contact and a missing rating', () async {
    late Map<String, dynamic> sent;
    final client = FeedbackClient(
      httpClient: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await client.send(message: 'un bug', type: FeedbackType.bug, contact: '   ');

    expect(sent.containsKey('rating'), isFalse);
    expect(sent.containsKey('contact'), isFalse);
  });

  test('sends images as multipart, capped at three', () async {
    late http.Request received;
    final client = FeedbackClient(
      httpClient: MockClient((req) async {
        received = req;
        return http.Response('{"ok":true}', 200);
      }),
    );

    final image = Uint8List.fromList(List.filled(32, 7));
    await client.send(
      message: 'bug avec captures',
      type: FeedbackType.bug,
      rating: 3,
      images: [image, image, image, image],
    );

    expect(received.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(received.bodyBytes);
    expect('name="images"'.allMatches(body).length, 3);
    expect(body, contains('name="message"'));
    expect(body, contains('bug avec captures'));
    expect(body, contains('name="rating"'));
    expect(body, contains('image/jpeg'));
  });

  test('a 413 from the host reads as images too large', () async {
    final client = FeedbackClient(
      httpClient: MockClient((_) async => http.Response('Request Entity Too Large', 413)),
    );

    await expectLater(
      client.send(message: 'grosse image', type: FeedbackType.bug, images: [Uint8List(10)]),
      throwsA(isA<FeedbackException>().having((e) => e.code, 'code', 'image_too_large')),
    );
  });

  test('maps the server error code to a readable message', () async {
    final client = FeedbackClient(
      httpClient: MockClient((_) async => http.Response('{"error":"rate_limited"}', 429)),
    );

    await expectLater(
      client.send(message: 'encore', type: FeedbackType.other),
      throwsA(isA<FeedbackException>()
          .having((e) => e.code, 'code', 'rate_limited')
          .having((e) => e.message, 'message', contains('heure'))),
    );
  });

  test('an unreadable error body still fails cleanly', () async {
    final client = FeedbackClient(
      httpClient: MockClient((_) async => http.Response('gateway down', 502)),
    );

    await expectLater(
      client.send(message: 'test', type: FeedbackType.other),
      throwsA(isA<FeedbackException>().having((e) => e.code, 'code', 'failed')),
    );
  });
}
