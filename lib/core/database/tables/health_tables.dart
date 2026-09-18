import 'package:drift/drift.dart';

/// One row per user per calendar day. Upserted repeatedly through the day
/// as HealthKit/Health Connect reports new totals — not an append-only
/// event stream, since "steps today" is a running total, not a series of
/// independent measurements.
class StepRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get date => dateTime()(); // truncated to day
  IntColumn get steps => integer()();
  IntColumn get target => integer().nullable()();
  TextColumn get source => text()(); // healthkit|health_connect|manual
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CardioSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get activityType => text()(); // walking|running|cycling|other
  RealColumn get distanceMeters => real().nullable()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get startedAt => dateTime()();
  TextColumn get eventId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class HiitSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get workoutId => text().nullable()();
  IntColumn get rounds => integer()();
  IntColumn get workSeconds => integer()();
  IntColumn get restSeconds => integer()();
  IntColumn get totalDurationSeconds => integer()();
  TextColumn get eventId => text()();
  DateTimeColumn get completedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Time-series log: every entry survives, no "latest wins" collapsing.
class WeightLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  RealColumn get weightKg => real()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get eventId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class BodyCompositionLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  RealColumn get bodyFatPercent => real().nullable()();
  RealColumn get muscleMassKg => real().nullable()();
  TextColumn get source => text().nullable()(); // scale|caliper|dexa|estimated
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get eventId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MeasurementLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get measurementType => text()(); // waist|chest|hip|arm|thigh
  RealColumn get valueCm => real()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get eventId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
