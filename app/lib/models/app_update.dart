class AppUpdate {
  final String version;
  final int build;

  const AppUpdate({required this.version, required this.build});

  factory AppUpdate.fromJson(Map<String, dynamic> j) => AppUpdate(
        version: j['version']?.toString() ?? '',
        build: int.tryParse(j['build']?.toString() ?? '') ?? 0,
      );
}
