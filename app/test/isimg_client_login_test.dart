import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/core/session_store.dart';
import 'package:isimg_app/isimg/isimg_client.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

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
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      ('check_account', '<meta http-equiv="refresh" content="0;URL=/fra/dashboard" />'),
    ]);

    final result = await client.login('2024666', 'right-password');

    expect(result, isA<LoginOk>());
  });

  test('an expired password is reported as such, not as a successful login',
      () async {
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      (
        'check_account',
        '<meta http-equiv="refresh" content="0;  URL=https://isimg.rnu.tn/fra/intranet/changepwd" >',
      ),
    ]);

    await expectLater(
      client.login('2024666', 'right-but-expired'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'password_expired')),
    );
  });

  test('no session is stored when the password turns out to be expired', () async {
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      ('check_account', '<meta http-equiv="refresh" content="0;URL=/fra/intranet/changepwd" />'),
    ]);

    await expectLater(client.login('2024666', 'pw'), throwsA(isA<ApiException>()));

    expect(await SessionStore().read(), isNull);
  });

  test('an expired password never reaches the emailed-code step', () async {
    final client = clientWith([
      ('/fra/home', _homeWithToken),
      ('check_account', '<meta http-equiv="refresh" content="0;URL=/fra/intranet/changepwd" />'),
    ]);

    await expectLater(
      client.login('2024666', 'pw'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'password_expired')),
    );
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
