import 'package:drift/drift.dart';

/// Challenge definitions are cloud-owned (cached locally read-only) since
/// they're shared across users; participation is local-first like
/// everything else and syncs up.
class Challenges extends Table {
  TextColumn get id => text()();
  TextColumn get key => text().unique()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get targetType => text()(); // steps|workouts|consistency_days|pull_up_sessions
  RealColumn get targetValue => real()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChallengeParticipations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get challengeId => text()();
  RealColumn get progressValue => real().withDefault(const Constant(0))();
  DateTimeColumn get joinedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
