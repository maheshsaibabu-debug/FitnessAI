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
      if (granted == false) return HealthPermissionStatus.denied;
      // null: platform can't disclose READ status (HealthKit's own
      // privacy model) — treat as granted-if-we-can-read, resolved by
      // actually attempting a read rather than blocking on this check.
      return HealthPermissionStatus.granted;
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
