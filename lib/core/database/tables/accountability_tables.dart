import 'package:drift/drift.dart';

class DailyPlans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get date => dateTime()(); // truncated to day
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyTasks extends Table {
  TextColumn get id => text()();
  TextColumn get dailyPlanId => text()();
  TextColumn get userId => text()();
  TextColumn get taskType => text()(); // workout|steps|nutrition|water|recovery
  TextColumn get refId => text().nullable()(); // e.g. workout id
  TextColumn get status => text().withDefault(
      const Constant('pending'))(); // pending|completed|partial|skipped|deferred
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Idempotent event recording how a task resolved, including the "why"
/// when skipped — this is the raw signal the adaptive engine learns from.
class TaskCompletions extends Table {
  TextColumn get id => text()();
  TextColumn get dailyTaskId => text()();
  TextColumn get userId => text()();
  TextColumn get status => text()(); // completed|partial|skipped|deferred
  TextColumn get skipReasonCode =>
      text().nullable()(); // no_time|too_tired|busy|sore|no_equipment|not_motivated|other
  TextColumn get note => text().nullable()();
  TextColumn get eventId => text()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CoachEvents extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get eventType => text()();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CoachInsights extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get insightType => text()();
  TextColumn get message => text()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get category =>
      text()(); // morning_plan|workout_reminder|step_reminder|evening_checkin|celebration|comeback
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get openedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NotificationPreferences extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get category => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get quietHoursStartMinute => integer().nullable()(); // minutes since midnight
  IntColumn get quietHoursEndMinute => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
