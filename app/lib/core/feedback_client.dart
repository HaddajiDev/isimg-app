import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_config.dart';

enum FeedbackType {
  bug('Bug'),
  idea('Idée'),
  other('Autre');

  final String label;

  const FeedbackType(this.label);
}

class FeedbackException implements Exception {
  final String code;

  const FeedbackException(this.code);

  String get message => switch (code) {
        'rate_limited' => 'Trop d\'envois. Réessayez dans une heure.',
        'message_required' => 'Écrivez au moins quelques mots.',
        'offline' => 'Pas de connexion. Vérifiez votre réseau et réessayez.',
        'image_too_large' => 'Les images sont trop lourdes. Retirez-en une et réessayez.',
        'too_many_images' => 'Trois images au maximum.',
        'bad_image' => 'Cette image ne peut pas être lue.',
        _ => 'L\'envoi a échoué. Réessayez plus tard.',
      };

  @override
  String toString() => 'FeedbackException($code)';
}

class FeedbackClient {
  static const maxImages = 3;

  final http.Client _http;

  FeedbackClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<void> send({
    required String message,
    required FeedbackType type,
    int? rating,
    String? contact,
    List<Uint8List> images = const [],
  }) async {
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final fields = <String, String>{
      'message': message.trim(),
      'type': type.name,
      if (rating != null) 'rating': '$rating',
      if (contact != null && contact.trim().isNotEmpty) 'contact': contact.trim(),
      'appVersion': ?appVersion,
      'device': _device(),
    };

    final http.Response res;
    try {
      if (images.isEmpty) {
        res = await _http
            .post(
              Uri.parse(kFeedbackApiUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                ...fields,
                'rating': ?rating,
              }),
            )
            .timeout(const Duration(seconds: 15));
      } else {
        final request = http.MultipartRequest('POST', Uri.parse(kFeedbackApiUrl))
          ..fields.addAll(fields);
        for (var i = 0; i < images.length && i < maxImages; i++) {
          request.files.add(http.MultipartFile.fromBytes(
            'images',
            images[i],
            filename: 'image$i.jpg',
            contentType: http.MediaType('image', 'jpeg'),
          ));
        }
        res = await http.Response.fromStream(
          await _http.send(request).timeout(const Duration(seconds: 45)),
        );
      }
    } on SocketException {
      throw const FeedbackException('offline');
    } catch (_) {
      throw const FeedbackException('failed');
    }

    if (res.statusCode == 200) return;
    String code = res.statusCode == 413 ? 'image_too_large' : 'failed';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) code = body['error'] as String;
    } catch (_) {}
    throw FeedbackException(code);
  }

  static Future<Uint8List> compressImage(Uint8List bytes) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      if (out.isEmpty) throw const FeedbackException('bad_image');
      return out;
    } on FeedbackException {
      rethrow;
    } catch (_) {
      throw const FeedbackException('bad_image');
    }
  }

  static String _device() {
    if (kIsWeb) return 'Web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}
