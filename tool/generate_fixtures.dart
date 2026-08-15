import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:statusmonitor/statusmonitor.dart';

void main() {
  final dir = p.join(Directory.current.path, 'test', 'fixtures');
  writeFixtureFiles(dir, generateFixtureSet());
  stdout.writeln('Wrote fixtures to $dir');
}
