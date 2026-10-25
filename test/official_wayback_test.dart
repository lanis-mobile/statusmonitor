import 'dart:convert';
import 'dart:io';

import 'package:statusmonitor/statusmonitor.dart';
import 'package:test/test.dart';

void main() {
  const root = 'test/fixtures/wayback';
  final manifest =
      jsonDecode(File('$root/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final snapshots = manifest['snapshots'] as List<dynamic>;

  for (final snapshot in snapshots.cast<Map<String, dynamic>>()) {
    test('Wayback ${snapshot['timestamp']} ${snapshot['originalUrl']}', () {
      final services = parseOfficialStatus(
        File('$root/${snapshot['fixture']}').readAsStringSync(),
      );
      final expected = (snapshot['expected'] as List)
          .cast<Map<String, dynamic>>();
      expect(services, hasLength(6));
      for (var i = 0; i < expected.length; i++) {
        final service = services[i];
        final original = expected[i];
        final reason =
            '${snapshot['archiveUrl']} ${original['id']} overview ${original['symbols']}';
        expect(service['id'], original['id'], reason: reason);
        expect(service['status'], original['status'], reason: reason);
        expect(service['maintenance'], original['maintenance'], reason: reason);
        expect(service['name'], isNotEmpty, reason: reason);
        expect(service['notice'], isNotEmpty, reason: reason);
        expect(service['update'], isNotEmpty, reason: reason);
        expect(
          service.keys,
          unorderedEquals([
            'id',
            'name',
            'status',
            'maintenance',
            'notice',
            'update',
          ]),
        );
      }
    });
  }

  test(
    'legacy overview skips the empty top anchor and preserves scheduled dates',
    () {
      final services = parseOfficialStatus(
        File('$root/20230330025034.html').readAsStringSync(),
      );
      expect(services.first['status'], 'operational');
      final learning = services.singleWhere((item) => item['id'] == 'LernSys');
      expect(learning['maintenance'], isTrue);
      expect(
        learning['update'],
        contains('03.04.23 ab 13:00 bis vsl. 20:00 Uhr'),
      );
      expect(learning['update'], contains('Letzte Aktualisierung 16.03.2023'));
    },
  );

  test(
    'preserves multiline current restrictions on the original 2024 page',
    () {
      final services = parseOfficialStatus(
        File('$root/20240103065341.html').readAsStringSync(),
      );
      final organisation = services.singleWhere(
        (item) => item['id'] == 'PaedOrg',
      );
      expect(organisation['status'], 'restricted');
      expect(organisation['maintenance'], isTrue);
      expect(
        organisation['notice'],
        contains('02.01. (morgens) bis vsl. 04.01 (mittags)'),
      );
      expect(organisation['notice'], contains('SPH-Downloads'));
      expect(
        organisation['notice'],
        contains('Letzte Einschränkung: 19.12.2023'),
      );
    },
  );

  test('preserves a historic login outage rather than reporting unknown', () {
    final services = parseOfficialStatus(
      File('$root/20240913214312.html').readAsStringSync(),
    );
    expect(services.first['id'], 'IdM');
    expect(services.first['status'], 'restricted');
    expect(
      services.singleWhere((item) => item['id'] == 'PaedNet')['maintenance'],
      isTrue,
    );
    expect(
      services.singleWhere((item) => item['id'] == 'Support')['status'],
      'operational',
    );
  });
}
