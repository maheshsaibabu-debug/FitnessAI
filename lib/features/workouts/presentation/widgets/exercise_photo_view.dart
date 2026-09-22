import 'package:flutter/material.dart';

/// Crossfades between an exercise's two bundled position photos
/// (start/end of the rep) from free-exercise-db — see
/// exercise_photo_registry.dart for attribution and the id->availability
/// registry. Bundled as local assets, not fetched over the network:
/// "lazy loading" and "caching" reduce to Flutter's own AssetImage cache,
/// which already handles both. What this widget actually owns is the
/// crossfade animation, a loading placeholder for the brief first decode,
/// and a graceful error state if a bundled file is ever missing/corrupt
/// (checked at import time — see tool/import_exercise_images.py — but
/// checked again here defensively rather than trusted blindly).
class ExercisePhotoView extends StatefulWidget {
  const ExercisePhotoView({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  State<ExercisePhotoView> createState() => _ExercisePhotoViewState();
}

class _ExercisePhotoViewState extends State<ExercisePhotoView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showFirstFrame = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _showFirstFrame = !_showFirstFrame);
          _controller.forward(from: 0);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final framePath = 'assets/data/exercise_images/${widget.exerciseId}-${_showFirstFrame ? 0 : 1}.jpg';

    return Container(
      height: 200,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Image.asset(
          framePath,
          key: ValueKey(framePath),
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
      ),
    );
  }
}
