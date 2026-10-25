// Offline audit of previously downloaded Wayback HTML; no network requests.
import 'dart:convert';
import 'dart:io';
import 'package:statusmonitor/statusmonitor.dart';

void main(List<String> paths) {
  if (paths.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/check_official_archives.dart <snapshot.html> ...',
    );
    exitCode = 64;
    return;
  }
  for (final path in paths) {
    try {
      final services = parseOfficialStatus(File(path).readAsStringSync());
      stdout.writeln(jsonEncode({'file': path, 'services': services}));
    } catch (error) {
      stderr.writeln('$path: $error');
      exitCode = 1;
    }
  }
}
