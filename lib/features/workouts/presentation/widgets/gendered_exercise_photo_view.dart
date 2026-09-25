import 'package:flutter/material.dart';

import 'exercise_animation_view.dart' show StickFigureSex;

/// A single male- or female-presenting demonstration photo (from Pexels —
/// see gendered_exercise_images_mapping.json) for an exercise
/// free-exercise-db had no safe match for. Unlike ExercisePhotoView there
/// is one photo per gender, not two frames to crossfade — [sex] picks
/// which file loads; `other`/unset falls back to the male photo rather
/// than guessing, since both exist and neither is more "default" than
/// the other.
class GenderedExercisePhotoView extends StatelessWidget {
  const GenderedExercisePhotoView({super.key, required this.exerciseId, required this.sex});

  final String exerciseId;
  final StickFigureSex sex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final genderFile = sex == StickFigureSex.female ? 'female' : 'male';
    final path = 'assets/data/exercise_images/$exerciseId-$genderFile.jpg';

    return Container(
      height: 200,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Image.asset(
        path,
        key: ValueKey(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text('Photo unavailable', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
