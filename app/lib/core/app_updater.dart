import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Where the update manifest lives. A plain JSON file in the bucket next to the
/// APKs — no server involved, which also means nothing to keep running and
/// nothing that a datacentre-blocking network can interfere with.
const updateManifestUrl = String.fromEnvironment(
  'UPDATE_MANIFEST_URL',
  defaultValue: 'https://f003.backblazeb2.com/file/isimg-app/latest.json',
);

/// A release described by the manifest.
///
/// Expected shape, with per-ABI downloads because the app ships split APKs:
///
/// ```json
/// {
///   "versionCode": 2,
///   "versionName": "1.0.1",
///   "notes": "Emploi hors ligne",
///   "apk": {
///     "arm64-v8a":   "https://.../isimg-1.0.1-arm64-v8a.apk",
///     "armeabi-v7a": "https://.../isimg-1.0.1-armeabi-v7a.apk",
///     "universal":   "https://.../isimg-1.0.1.apk"
///   }
/// }
/// ```
class AppRelease {
  final int versionCode;
  final String versionName;
  final String? notes;
  final Map<String, String> apkUrls;

  const AppRelease({
    required this.versionCode,
    required this.versionName,
    this.notes,
    required this.apkUrls,
  });

  static AppRelease? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final versionCode = switch (raw['versionCode']) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    if (versionCode == null) return null;

    final apk = raw['apk'];
    final urls = <String, String>{
      if (apk is Map)
        for (final entry in apk.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      // Tolerate a single-URL manifest too.
      if (raw['apkUrl'] is String) 'universal': raw['apkUrl'] as String,
    };
    if (urls.isEmpty) return null;

    return AppRelease(
      versionCode: versionCode,
      versionName: raw['versionName'] as String? ?? '$versionCode',
      notes: raw['notes'] as String?,
      apkUrls: urls,
    );
  }

  /// Download for this device's CPU, falling back to the universal build.
  String? urlFor(Iterable<String> supportedAbis) {
    for (final abi in supportedAbis) {
      final url = apkUrls[abi];
      if (url != null) return url;
    }
    return apkUrls['universal'];
  }
}

enum UpdateStage { idle, checking, available, downloading, readyToInstall, failed }

class UpdateState {
  final UpdateStage stage;
  final AppRelease? release;

  /// 0..1 while downloading, or null when unknown (server sent no length).
  final double? progress;
  final String? error;

  const UpdateState({
    this.stage = UpdateStage.idle,
    this.release,
    this.progress,
    this.error,
  });

  bool get hasUpdate =>
      release != null &&
      (stage == UpdateStage.available ||
          stage == UpdateStage.downloading ||
          stage == UpdateStage.readyToInstall);
}

/// Checks the bucket for a newer build and hands the APK to the system
/// installer.
///
/// Android deliberately gives no way for an ordinary app to install a package
/// without the user agreeing, so the final step is always the platform's own
/// installer screen. Everything before it — noticing, downloading, verifying —
/// happens without the student doing anything.
class AppUpdater {
  final Dio _dio;

  /// Injected so tests can supply a fixed value instead of reading the platform.
  final Future<int> Function() readCurrentVersionCode;
  final Future<List<String>> Function() readSupportedAbis;

  AppUpdater({
    Dio? dio,
    Future<int> Function()? currentVersionCode,
    Future<List<String>> Function()? supportedAbis,
  })  : _dio = dio ?? Dio(),
        readCurrentVersionCode = currentVersionCode ?? _platformVersionCode,
        readSupportedAbis = supportedAbis ?? _platformAbis;

  static Future<int> _platformVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<List<String>> _platformAbis() async {
    // Split APKs are per-ABI, so the right one depends on the CPU. Dart cannot
    // read Build.SUPPORTED_ABIS directly; the OS version string is enough to
    // tell 64- from 32-bit, and universal is always a safe fallback.
    if (!Platform.isAndroid) return const [];
    final is64Bit = Platform.version.contains('arm64') ||
        Platform.operatingSystemVersion.contains('aarch64') ||
        Platform.operatingSystemVersion.contains('arm64');
    return is64Bit ? const ['arm64-v8a', 'armeabi-v7a'] : const ['armeabi-v7a'];
  }

  /// Returns the newer release, or null when already up to date.
  Future<AppRelease?> check() async {
    final response = await _dio.get<String>(
      updateManifestUrl,
      options: Options(
        responseType: ResponseType.plain,
        // Buckets cache aggressively; a stale manifest would hide a release.
        headers: const {'Cache-Control': 'no-cache'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('manifest returned ${response.statusCode}');
    }

    final release = AppRelease.tryParse(jsonDecode(response.data ?? ''));
    if (release == null) throw Exception('manifest is malformed');

    return release.versionCode > await readCurrentVersionCode() ? release : null;
  }

  /// Downloads the APK for this device, reporting progress as a 0..1 fraction.
  Future<File> download(
    AppRelease release, {
    void Function(double? progress)? onProgress,
  }) async {
    final url = release.urlFor(await readSupportedAbis());
    if (url == null) throw Exception('no download for this device');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/isimg-${release.versionName}.apk');
    // A partial file from an interrupted attempt would fail to install.
    if (await file.exists()) await file.delete();

    await _dio.download(
      url,
      file.path,
      onReceiveProgress: (received, total) {
        onProgress?.call(total > 0 ? received / total : null);
      },
    );

    return file;
  }

  /// Opens the downloaded APK, which brings up the system installer.
  ///
  /// The install only succeeds if the new APK is signed with the same key as the
  /// installed one — Android refuses a signature change outright.
  Future<void> install(File apk) async {
    final result = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      debugPrint('updater: installer refused — ${result.type} ${result.message}');
      throw Exception(result.message);
    }
  }
}
