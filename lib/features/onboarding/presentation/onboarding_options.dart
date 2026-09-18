/// (value, label) pairs for the onboarding wizard's choice controls —
/// product spec §16. Kept in one place so the persisted values (which
/// downstream engines pattern-match on, e.g. `primaryGoal == 'fat_loss'`)
/// stay in sync with what the UI offers.
const List<(String value, String label)> kGoalOptions = [
  ('fat_loss', 'Fat loss'),
  ('muscle_gain', 'Muscle gain'),
  ('weight_gain', 'Weight gain'),
  ('maintain', 'Maintain'),
  ('strength', 'Strength'),
  ('endurance', 'Endurance'),
  ('cardio', 'Cardiovascular fitness'),
  ('mobility', 'Mobility'),
  ('general', 'General fitness'),
  ('consistency', 'Consistency'),
];

const List<(String value, String label)> kEquipmentOptions = [
  ('none', 'None (bodyweight only)'),
  ('pull_up_bar', 'Pull-up bar'),
  ('dumbbells', 'Dumbbells'),
  ('barbell', 'Barbell'),
  ('bench', 'Bench'),
  ('resistance_bands', 'Resistance bands'),
  ('kettlebell', 'Kettlebell'),
  ('machines', 'Machines'),
  ('full_gym', 'Full gym'),
];

const List<(String value, String label)> kTrainingLocationOptions = [
  ('gym', 'Gym'),
  ('home', 'Home'),
  ('outdoor', 'Outdoor'),
  ('mixed', 'Mixed'),
];

const List<(String value, String label)> kFitnessLevelOptions = [
  ('beginner', 'Beginner'),
  ('intermediate', 'Intermediate'),
  ('advanced', 'Advanced'),
];

const List<(String value, String label)> kDietaryPreferenceOptions = [
  ('omnivore', 'Omnivore'),
  ('vegetarian', 'Vegetarian'),
  ('vegan', 'Vegan'),
  ('pescatarian', 'Pescatarian'),
  ('other', 'Other'),
];

const List<(String value, String label)> kPreferredTimeOptions = [
  ('morning', 'Morning'),
  ('afternoon', 'Afternoon'),
  ('evening', 'Evening'),
];
