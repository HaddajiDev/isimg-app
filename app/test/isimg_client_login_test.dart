import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/isimg/isimg_client.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Answers requests in strict sequence, so the same URL requested twice gets
/// whichever body is next in the script rather than always matching the
/// first entry that contains the URL.
class ScriptedAdapter implements HttpClientAdapter {
  final List<(String urlContains, String body)> responses;
  var _cursor = 0;

  ScriptedAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_cursor >= responses.length) {
      throw StateError('no more scripted responses, but got ${options.path}');
    }
    final (expectedNeedle, body) = responses[_cursor];
    if (!options.path.contains(expectedNeedle)) {
      throw StateError(
        'expected request #$_cursor to contain "$expectedNeedle", got ${options.path}',
      );
    }
    _cursor++;
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.textPlainContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _homeWithToken = '<input type="hidden" name="token" value="tok123" />';

IsimgClient clientWith(List<(String, String)> script) {
  final dio = Dio()..httpClientAdapter = ScriptedAdapter(script);
  return IsimgClient(dio: dio);
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
  });

  test('wrong credentials are rejected when check_account re-renders the login page',
      () async {
    // The real captured login page, exactly as check_account would re-serve
    // it for a rejected attempt: no extra fetch needed to notice this.
    final loginPage = fixture('login_page.html');
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      ('check_account', loginPage),
    ]);

    await expectLater(
      client.login('2024666', 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
  });

  test('wrong credentials are rejected even if that response also carries a redirect',
      () async {
    // A meta-refresh alone was the original bug's blind spot: this is still
    // the login page, so it must not be trusted just because it redirects.
    final loginPage = fixture('login_page.html').replaceFirst(
      '</head>',
      '<meta http-equiv="refresh" content="0;URL=/fra/home" /></head>',
    );
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      ('check_account', loginPage),
    ]);

    await expectLater(
      client.login('2024666', 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
  });

  test('a real login succeeds without any extra fetch of the redirect target',
      () async {
    // The regression this guards against: the previous fix re-fetched the
    // redirect target and broke on this exact path. The script only has two
    // entries, so a third request would fail the test outright.
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      ('check_account', '<meta http-equiv="refresh" content="0;URL=/fra/dashboard" />'),
    ]);

    final result = await client.login('2024666', 'right-password');

    expect(result, isA<LoginOk>());
  });

  test('the emailed-code path is unaffected by the new check', () async {
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      ('check_account', '<meta http-equiv="refresh" content="0;URL=/fra/intranet/verify_2fa" />'),
      ('verify_2fa', '<input type="hidden" name="token2fa" value="tok2fa" />'),
    ]);

    final result = await client.login('2024666', 'right-password');

    expect(result, isA<LoginOtpRequired>());
  });
}
