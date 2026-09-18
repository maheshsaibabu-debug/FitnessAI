/// In-progress onboarding answers, held in memory only until [submit] is
/// called — nothing here touches the database until the user confirms on
/// the review step. Plain immutable class with copyWith rather than
/// Freezed: short-lived UI state that doesn't need serialization or
/// union types, so the extra codegen isn't worth it here.
class OnboardingDraft {
  const OnboardingDraft({
    this.name = '',
    this.sex,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.primaryGoal,
    this.fitnessLevel,
    this.trainingLocation,
    this.equipment = const {},
    this.availabilityDaysPerWeek = 3,
    this.availabilityMinutesPerSession = 30,
    this.preferredTimeOfDay,
    this.dietaryPreference,
    this.dietaryRestrictions = const {},
    this.baselinePushUps,
    this.baselineSquats,
    this.baselinePullUps,
    this.baselinePlankSeconds,
  });

  final String name;
  final String? sex; // male | female | other | undisclosed
  final DateTime? dateOfBirth;
  final double? heightCm;
  final double? weightKg;

  final String? primaryGoal; // fat_loss|muscle_gain|weight_gain|maintain|strength|endurance|cardio|mobility|general|consistency
  final String? fitnessLevel; // beginner|intermediate|advanced (self-reported; refined by the baseline test if provided)
  final String? trainingLocation; // gym|home|outdoor|mixed
  final Set<String> equipment;

  final int availabilityDaysPerWeek;
  final int availabilityMinutesPerSession;
  final String? preferredTimeOfDay; // morning|afternoon|evening

  final String? dietaryPreference; // vegetarian|vegan|omnivore|pescatarian|other
  final Set<String> dietaryRestrictions;

  final int? baselinePushUps;
  final int? baselineSquats;
  final int? baselinePullUps;
  final int? baselinePlankSeconds;

  bool get hasBaselineData =>
      baselinePushUps != null || baselineSquats != null || baselinePullUps != null || baselinePlankSeconds != null;

  bool get isPersonalStepValid =>
      name.trim().isNotEmpty && sex != null && dateOfBirth != null && heightCm != null && weightKg != null;

  bool get isGoalsStepValid => primaryGoal != null;

  bool get isLevelStepValid => fitnessLevel != null && trainingLocation != null;

  bool get isAvailabilityStepValid => availabilityDaysPerWeek > 0 && availabilityMinutesPerSession > 0;

  bool get isReadyToSubmit => isPersonalStepValid && isGoalsStepValid && isLevelStepValid && isAvailabilityStepValid;

  OnboardingDraft copyWith({
    String? name,
    String? sex,
    DateTime? dateOfBirth,
    double? heightCm,
    double? weightKg,
    String? primaryGoal,
    String? fitnessLevel,
    String? trainingLocation,
    Set<String>? equipment,
    int? availabilityDaysPerWeek,
    int? availabilityMinutesPerSession,
    String? preferredTimeOfDay,
    String? dietaryPreference,
    Set<String>? dietaryRestrictions,
    int? baselinePushUps,
    int? baselineSquats,
    int? baselinePullUps,
    int? baselinePlankSeconds,
  }) {
    return OnboardingDraft(
      name: name ?? this.name,
      sex: sex ?? this.sex,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      trainingLocation: trainingLocation ?? this.trainingLocation,
      equipment: equipment ?? this.equipment,
      availabilityDaysPerWeek: availabilityDaysPerWeek ?? this.availabilityDaysPerWeek,
      availabilityMinutesPerSession: availabilityMinutesPerSession ?? this.availabilityMinutesPerSession,
      preferredTimeOfDay: preferredTimeOfDay ?? this.preferredTimeOfDay,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      baselinePushUps: baselinePushUps ?? this.baselinePushUps,
      baselineSquats: baselineSquats ?? this.baselineSquats,
      baselinePullUps: baselinePullUps ?? this.baselinePullUps,
      baselinePlankSeconds: baselinePlankSeconds ?? this.baselinePlankSeconds,
    );
  }
}
