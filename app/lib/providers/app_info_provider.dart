import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Read once and kept alive for the app's lifetime — the version cannot
/// change while it is running, so there is nothing to ever refetch.
final appInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());
