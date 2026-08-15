import 'dart:io';

import 'package:path/path.dart' as p;

enum AppMode { live, fixture }

class AppConfig {
  AppConfig({
    required this.mode,
    required this.port,
    required this.databasePath,
    required this.staticDir,
    required this.schoolId,
    required this.username,
    required this.password,
    required this.now,
    required this.fixtureDir,
    this.probeTimeout = const Duration(seconds: 45),
    this.holidayTtl = const Duration(days: 7),
    this.retention = const Duration(days: 730),
  });

  final AppMode mode;
  final int port;
  final String databasePath;
  final String staticDir;
  final int schoolId;
  final String username;
  final String password;
  final int? now;
  final String fixtureDir;
  final Duration probeTimeout;
  final Duration holidayTtl;
  final Duration retention;

  bool get isFixture => mode == AppMode.fixture;

  factory AppConfig.fromEnvironment({Map<String, String>? env}) {
    final e = env ?? Platform.environment;
    final mode = e['STATUSMONITOR_MODE'] == 'fixture'
        ? AppMode.fixture
        : AppMode.live;
    final nowRaw = e['STATUSMONITOR_NOW'];
    return AppConfig(
      mode: mode,
      port: int.tryParse(e['PORT'] ?? '') ?? 8080,
      databasePath:
          e['DATABASE_PATH'] ??
          (mode == AppMode.fixture ? ':memory:' : 'data/status.db'),
      staticDir:
          e['STATUSMONITOR_STATIC_DIR'] ??
          p.join(Directory.current.path, 'frontend', 'dist'),
      schoolId: int.tryParse(e['LANIS_SCHOOL_ID'] ?? '') ?? 0,
      username: e['LANIS_USERNAME'] ?? '',
      password: e['LANIS_PASSWORD'] ?? '',
      now: nowRaw == null || nowRaw.isEmpty ? null : int.parse(nowRaw),
      fixtureDir:
          e['STATUSMONITOR_FIXTURE_DIR'] ??
          p.join(Directory.current.path, 'test', 'fixtures'),
    );
  }

  void validate() {
    if (isFixture) return;
    if (schoolId <= 0 || username.isEmpty || password.isEmpty) {
      throw StateError(
        'LANIS_SCHOOL_ID, LANIS_USERNAME and LANIS_PASSWORD are required '
        'in live mode.',
      );
    }
  }
}
