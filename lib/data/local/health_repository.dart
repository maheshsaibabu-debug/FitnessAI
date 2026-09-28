import 'dart:io' show Platform;

import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:health/health.dart';
import 'package:logging/logging.dart';

final _log = Logger('HealthRepository');

enum HealthPermissionStatus { granted, denied, unavailable }

/// Wraps the `health` plugin (HealthKit on iOS, Health Connect on
/// Android) behind one interface. Every call is defensive: a missing
/// plugin registration, a denied permission, or an unsupported platform
/// all degrade to a null/false result rather than throwing — steps are a
/// best-effort enhancement (product spec §22), never something the rest
/// of the app can assume succeeded. See docs/OFFLINE_FIRST.md.
class HealthRepository {
  HealthRepository({Health? health}) : _health = health ?? Health() {
    _health.configure();
  }

  final Health _health;

  /// The `StepRecords.source` value to write when a reading came from
  /// this plugin — kept here so callers never need to branch on platform
  /// themselves.
  String get sourceLabel => Platform.isIOS ? 'healthkit' : 'health_connect';

  static const _stepsTypes = [HealthDataType.STEPS];

  Future<HealthPermissionStatus> checkStepsPermission() async {
    try {
      final granted = await _health.hasPermissions(_stepsTypes);
      if (granted == true) return HealthPermissionStatus.granted;
      // false and null both mean "we can't confirm READ access" here, but
      // for different reasons the UI must not conflate: on iOS, `false` is
      // never actually returned for a READ-only check like this one —
      // HealthKit's privacy model always yields null (undetermined),
      // resolved by attempting a real read rather than blocking on this
      // check. On Android, Health Connect always answers definitively —
      // `false` there just as often means "never asked" as "denied", since
      // hasPermissions() can't tell those apart. Reporting that as
      // `denied` left a fresh install permanently stuck on "permission
      // denied — reconnect from Settings" despite the system dialog never
      // having been shown. `unavailable` is the honest state for both:
      // it's what drives the UI's "Connect Health" button, which actually
      // triggers the real permission prompt — Android lets that be
      // retried freely, unlike iOS's post-decline lockout.
      return HealthPermissionStatus.unavailable;
    } on MissingPluginException {
      return HealthPermissionStatus.unavailable;
    } on PlatformException catch (e) {
      _log.warning('checkStepsPermission failed: $e');
      return HealthPermissionStatus.unavailable;
    }
  }

  Future<HealthPermissionStatus> requestStepsPermission() async {
    try {
      final granted = await _health.requestAuthorization(
        _stepsTypes,
        permissions: const [HealthDataAccess.READ],
      );
      return granted ? HealthPermissionStatus.granted : HealthPermissionStatus.denied;
    } on MissingPluginException {
      return HealthPermissionStatus.unavailable;
    } on PlatformException catch (e) {
      _log.warning('requestStepsPermission failed: $e');
      return HealthPermissionStatus.unavailable;
    }
  }

  /// Steps recorded since local midnight, or null if unavailable for any
  /// reason (no permission, plugin not registered on this platform/build,
  /// simulator with no Health data). Null means "fall back to manual
  /// entry," never "assume zero."
  Future<int?> readTodaySteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      return await _health.getTotalStepsInInterval(startOfDay, now);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      _log.warning('readTodaySteps failed: $e');
      return null;
    }
  }
}
