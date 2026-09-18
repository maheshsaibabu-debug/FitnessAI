import 'package:drift/drift.dart';

/// The single local user profile. Even though Supabase Auth may know about
/// many users historically, the device only ever holds the profile of
/// whoever is currently signed in — this is not a multi-tenant table.
class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get authUserId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get sex => text()(); // male | female | other | undisclosed
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get trainingLocation => text().nullable()(); // gym|home|outdoor|mixed
  TextColumn get equipmentJson => text().withDefault(const Constant('[]'))();
  TextColumn get fitnessLevel => text().nullable()(); // beginner|intermediate|advanced
  IntColumn get availabilityDaysPerWeek => integer().nullable()();
  IntColumn get availabilityMinutesPerSession => integer().nullable()();
  TextColumn get preferredTimeOfDay => text().nullable()(); // morning|afternoon|evening
  TextColumn get dietaryPreference => text().nullable()(); // vegetarian|vegan|omnivore|pescatarian|other
  TextColumn get dietaryRestrictionsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class FitnessGoals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get goalType =>
      text()(); // fat_loss|muscle_gain|weight_gain|maintain|strength|endurance|cardio|mobility|general|consistency
  BoolColumn get isPrimary => boolean().withDefault(const Constant(true))();
  RealColumn get targetValue => real().nullable()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lightweight assessment performed right after onboarding; future
/// performance is compared against this baseline, not an arbitrary origin.
class FitnessBaselines extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get baselineDate => dateTime()();
  IntColumn get pushUpsReps => integer().nullable()();
  IntColumn get squatsReps => integer().nullable()();
  IntColumn get pullUpsReps => integer().nullable()();
  IntColumn get plankSeconds => integer().nullable()();
  IntColumn get walkJogMinutes => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
