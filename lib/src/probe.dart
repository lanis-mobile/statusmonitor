import 'dart:async';
import 'dart:io';

import 'package:liblanis/easy_client.dart';

import 'clock.dart';
import 'config.dart';
import 'database.dart';
import 'models.dart';

class ProbeService {
  ProbeService({required this.db, required this.config, required this.clock});

  final StatusDatabase db;
  final AppConfig config;
  final Clock clock;

  Future<CheckRecord> runOnce() async {
    final started = DateTime.now();
    var code = CheckCode.ok;
    var ok = 1;
    int? ms;

    EasyLanisClient? client;
    try {
      client = EasyLanisClient.ephemeral(
        schoolId: config.schoolId,
        username: config.username,
        password: config.password,
        userAgent: 'statusmonitor/1.0 (lanis-mobile)',
      );
      await client.login().timeout(config.probeTimeout);
      ms = DateTime.now().difference(started).inMilliseconds;
      try {
        await client.logout();
      } catch (_) {}
    } on TimeoutException {
      code = CheckCode.timeout;
      ok = 0;
    } on LoginTimeoutException {
      code = CheckCode.timeout;
      ok = 0;
    } on WrongCredentialsException {
      code = CheckCode.auth;
      ok = 0;
    } on CredentialsIncompleteException {
      code = CheckCode.auth;
      ok = 0;
    } on UnauthorizedException {
      code = CheckCode.auth;
      ok = 0;
    } on NetworkException {
      code = CheckCode.http;
      ok = 0;
    } on NoConnectionException {
      code = CheckCode.http;
      ok = 0;
    } on LanisDownException {
      code = CheckCode.http;
      ok = 0;
    } catch (error, stack) {
      stderr.writeln('Probe failed: $error');
      stderr.writeln(stack);
      code = CheckCode.error;
      ok = 0;
    } finally {
      try {
        await client?.dispose();
      } catch (_) {}
    }

    final record = CheckRecord(
      ts: clock.nowSeconds,
      ok: ok,
      ms: ok == 1 ? ms : null,
      code: code,
    );
    db.insertCheck(record);
    db.maybeMaintain(record.ts);
    return record;
  }
}
