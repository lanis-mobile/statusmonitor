// Manual smoke check; performs one public request chain without SPH credentials.
import 'dart:io';
import 'package:statusmonitor/statusmonitor.dart';

Future<void> main() async {
  final db = StatusDatabase.open(':memory:');
  try {
    final official = OfficialStatusService(db: db, clock: Clock());
    await official.refresh();
    final data = official.payload();
    final services = data['services'] as List;
    stdout.writeln(
      'Official services: ${services.length}; stale: ${data['stale']}',
    );
    if (services.length != 6 || data['stale'] != false) exitCode = 1;
  } finally {
    db.dispose();
  }
}
