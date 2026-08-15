import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;

import 'app.dart';
import 'clock.dart';
import 'config.dart';
import 'database.dart';
import 'fixtures.dart';
import 'holidays.dart';
import 'probe.dart';

Future<HttpServer> runServer({AppConfig? config}) async {
  final cfg = config ?? AppConfig.fromEnvironment();
  cfg.validate();

  final clock = Clock(fixedNow: cfg.now);
  final db = StatusDatabase.open(cfg.databasePath);
  final holidays = HolidayService(db: db, config: cfg, clock: clock);
  final probe = ProbeService(db: db, config: cfg, clock: clock);

  if (cfg.isFixture) {
    final now = cfg.now ?? fixtureNow;
    final fixtures = File('${cfg.fixtureDir}/checks.json').existsSync()
        ? loadFixtures(cfg.fixtureDir)
        : generateFixtureSet(now: now);
    seedDatabase(db, fixtures);
  } else {
    await holidays.refreshIfNeeded();
    try {
      await probe.runOnce();
    } catch (error, stack) {
      stderr.writeln('Initial probe failed: $error');
      stderr.writeln(stack);
    }
  }

  final app = StatusApp(db: db, config: cfg, clock: clock);
  final server = await io.serve(app.handler, InternetAddress.anyIPv4, cfg.port);
  stderr.writeln(
    'Listening on http://${server.address.address}:${server.port}',
  );

  Timer? probeTimer;
  Timer? holidayTimer;
  if (!cfg.isFixture) {
    probeTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        await probe.runOnce();
      } catch (error, stack) {
        stderr.writeln('Probe failed: $error');
        stderr.writeln(stack);
      }
    });
    holidayTimer = Timer.periodic(const Duration(hours: 24), (_) {
      unawaited(holidays.refreshIfNeeded());
    });
  }

  server.autoCompress = true;
  _attachShutdown(server, db, probeTimer, holidayTimer);
  return server;
}

void _attachShutdown(
  HttpServer server,
  StatusDatabase db,
  Timer? probeTimer,
  Timer? holidayTimer,
) {
  var closing = false;
  Future<void> shutdown(String signal) async {
    if (closing) return;
    closing = true;
    stderr.writeln('Shutting down ($signal)');
    probeTimer?.cancel();
    holidayTimer?.cancel();
    await server.close(force: true);
    db.dispose();
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown('SIGINT'));
  ProcessSignal.sigterm.watch().listen((_) => shutdown('SIGTERM'));
}
