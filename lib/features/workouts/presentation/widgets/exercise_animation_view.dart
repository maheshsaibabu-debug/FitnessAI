import 'dart:math' as math;

import 'package:flutter/material.dart';

enum StickFigureSex { male, female, other }

enum _Motion { pushUp, squat, plank, pullUp, mountainClimber, hipRaise }

/// A small set of procedurally-animated figure loops, one per motion
/// pattern, gender-varied by a simple silhouette cue (hair) — not a
/// photorealistic demonstration. Real photo/video exercise media needs
/// licensed assets this project doesn't have; this is a genuine, working
/// substitute rather than a static placeholder image, intentionally
/// scoped to the handful of exercises below rather than claiming
/// coverage of the whole library. Anything not in [_motionFor] falls
/// back to [_UnavailableDemo], which is honest about not having one.
class ExerciseAnimationView extends StatefulWidget {
  const ExerciseAnimationView({super.key, required this.exerciseId, required this.sex});

  final String exerciseId;
  final StickFigureSex sex;

  static const Map<String, _Motion> _motionFor = {
    'push-up': _Motion.pushUp,
    'incline-push-up': _Motion.pushUp,
    'diamond-push-up': _Motion.pushUp,
    'squat': _Motion.squat,
    'goblet-squat': _Motion.squat,
    'barbell-back-squat': _Motion.squat,
    'plank': _Motion.plank,
    'side-plank': _Motion.plank,
    'pull-up': _Motion.pullUp,
    'chin-up': _Motion.pullUp,
    'assisted-pull-up': _Motion.pullUp,
    'weighted-pull-up': _Motion.pullUp,
    'mountain-climber': _Motion.mountainClimber,
    'lunge': _Motion.squat,
    'split-squat': _Motion.squat,
    'glute-bridge': _Motion.hipRaise,
    'hip-thrust': _Motion.hipRaise,
  };

  @override
  State<ExerciseAnimationView> createState() => _ExerciseAnimationViewState();
}

class _ExerciseAnimationViewState extends State<ExerciseAnimationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _eased;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    // Ease both directions of the ping-pong so the rep reads as a real
    // muscle-driven movement (slow-fast-slow) instead of a mechanical
    // linear back-and-forth.
    _eased = CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = ExerciseAnimationView._motionFor[widget.exerciseId];
    final scheme = Theme.of(context).colorScheme;

    if (motion == null) {
      return _UnavailableDemo(color: scheme.outline);
    }

    return Container(
      height: 176,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _eased,
        builder: (context, _) => CustomPaint(
          size: const Size(double.infinity, 176),
          painter: _FigurePainter(
            progress: _eased.value,
            motion: motion,
            sex: widget.sex,
            bodyColor: scheme.primary,
            groundColor: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _UnavailableDemo extends StatelessWidget {
  const _UnavailableDemo({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.accessibility_new, size: 32, color: color),
            const SizedBox(height: 6),
            Text('No demo animation for this exercise yet', style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Draws a simple filled humanoid figure — thick round-capped strokes for
/// limbs (reading as smooth capsule shapes, not thin wireframe lines)
/// plus filled joint/head circles so segments blend into one continuous
/// silhouette rather than showing visible seams.
class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.progress,
    required this.motion,
    required this.sex,
    required this.bodyColor,
    required this.groundColor,
  });

  final double progress; // 0..1, eased, oscillates via CurvedAnimation(reverse)
  final _Motion motion;
  final StickFigureSex sex;
  final Color bodyColor;
  final Color groundColor;

  static const _limbWidth = 15.0;
  static const _jointRadius = 8.0;
  static const _headRadius = 15.0;

  @override
  void paint(Canvas canvas, Size size) {
    final limbPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _limbWidth
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    final groundPaint = Paint()
      ..color = groundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.save();
    const localWidth = 200.0;
    const localHeight = 150.0;
    final scale = math.min(size.width / localWidth, size.height / localHeight);
    canvas.translate(
      (size.width - localWidth * scale) / 2,
      (size.height - localHeight * scale) / 2,
    );
    canvas.scale(scale);

    switch (motion) {
      case _Motion.pushUp:
        _paintGroundLine(canvas, groundPaint, 122);
        _paintPushUp(canvas, limbPaint, jointPaint);
      case _Motion.squat:
        _paintGroundLine(canvas, groundPaint, 128);
        _paintSquat(canvas, limbPaint, jointPaint);
      case _Motion.plank:
        _paintGroundLine(canvas, groundPaint, 112);
        _paintPlank(canvas, limbPaint, jointPaint);
      case _Motion.pullUp:
        _paintPullUp(canvas, limbPaint, jointPaint);
      case _Motion.mountainClimber:
        _paintGroundLine(canvas, groundPaint, 122);
        _paintMountainClimber(canvas, limbPaint, jointPaint);
      case _Motion.hipRaise:
        _paintGroundLine(canvas, groundPaint, 112);
        _paintHipRaise(canvas, limbPaint, jointPaint);
    }

    canvas.restore();
  }

  void _paintGroundLine(Canvas canvas, Paint paint, double y) {
    canvas.drawLine(Offset(15, y), Offset(185, y), paint);
  }

  void _limb(Canvas canvas, Paint limbPaint, Paint jointPaint, Offset a, Offset b) {
    canvas.drawLine(a, b, limbPaint);
    canvas.drawCircle(a, _jointRadius, jointPaint);
    canvas.drawCircle(b, _jointRadius, jointPaint);
  }

  void _head(Canvas canvas, Paint jointPaint, Offset center) {
    canvas.drawCircle(center, _headRadius, jointPaint);
    if (sex == StickFigureSex.female) {
      // A simple ponytail cue — the only silhouette differentiation a
      // simplified figure can meaningfully carry.
      final path = Path()
        ..moveTo(center.dx + 11, center.dy - 8)
        ..quadraticBezierTo(center.dx + 28, center.dy, center.dx + 12, center.dy + 18);
      canvas.drawPath(
        path,
        Paint()
          ..color = jointPaint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintPushUp(Canvas canvas, Paint limbPaint, Paint jointPaint) {
    final drop = math.sin(progress * math.pi) * 16; // eased via the animation itself
    final shoulder = Offset(65, 70 + drop);
    final hip = Offset(128, 64 + drop * 0.6);
    final hand = const Offset(65, 118);
    final foot = const Offset(175, 108);
    final headCenter = Offset(shoulder.dx - 16, shoulder.dy - 8);

    _limb(canvas, limbPaint, jointPaint, hip, foot); // legs
    _limb(canvas, limbPaint, jointPaint, shoulder, hip); // torso
    _limb(canvas, limbPaint, jointPaint, shoulder, hand); // arm
    _head(canvas, jointPaint, headCenter);
  }

  void _paintSquat(Canvas canvas, Paint limbPaint, Paint jointPaint) {
    final bend = progress; // 0 standing, 1 fully squatted
    final head = Offset(100, 22 + bend * 32);
    final shoulder = Offset(100, 40 + bend * 32);
    final hip = Offset(100, 68 + bend * 32);
    final knee = Offset(100 + bend * 16, 100 + bend * 6);
    final foot = const Offset(100, 128);
    final handOffsetY = 34 + bend * 12;

    _limb(canvas, limbPaint, jointPaint, hip, knee);
    _limb(canvas, limbPaint, jointPaint, knee, foot);
    _limb(canvas, limbPaint, jointPaint, shoulder, hip);
    _limb(canvas, limbPaint, jointPaint, shoulder, Offset(shoulder.dx - 24, shoulder.dy + handOffsetY));
    _limb(canvas, limbPaint, jointPaint, shoulder, Offset(shoulder.dx + 24, shoulder.dy + handOffsetY));
    _head(canvas, jointPaint, head);
  }

  void _paintPlank(Canvas canvas, Paint limbPaint, Paint jointPaint) {
    // A hold, not a repeated movement — a subtle idle bob conveys "live"
    // without implying a rep cadence that doesn't exist for this exercise.
    final bob = math.sin(progress * math.pi) * 2;
    final shoulder = Offset(65, 78 + bob);
    final hip = Offset(128, 76 + bob);
    final elbow = const Offset(65, 112);
    final foot = const Offset(180, 108);
    final head = Offset(shoulder.dx - 16, shoulder.dy - 6);

    _limb(canvas, limbPaint, jointPaint, hip, foot);
    _limb(canvas, limbPaint, jointPaint, shoulder, hip);
    _limb(canvas, limbPaint, jointPaint, shoulder, elbow);
    _head(canvas, jointPaint, head);
  }

  void _paintPullUp(Canvas canvas, Paint limbPaint, Paint jointPaint) {
    final lift = progress; // 0 hanging, 1 chin over the bar
    final barPaint = Paint()
      ..color = groundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const barLeft = Offset(55, 18);
    const barRight = Offset(145, 18);
    final head = Offset(100, 32 + (1 - lift) * 44);
    final shoulder = Offset(100, 48 + (1 - lift) * 44);
    final hip = Offset(100, 86 + (1 - lift) * 32);
    final foot = Offset(100, 126 + (1 - lift) * 8);

    canvas.drawLine(barLeft, barRight, barPaint);
    _limb(canvas, limbPaint, jointPaint, barLeft, shoulder);
    _limb(canvas, limbPaint, jointPaint, barRight, shoulder);
    _limb(canvas, limbPaint, jointPaint, shoulder, hip);
    _limb(canvas, limbPaint, jointPaint, hip, foot);
    _head(canvas, jointPaint, head);
  }

  void _paintMountainClimber(Canvas canvas, Paint limbPaint, Paint jointPaint) {
    // Plank base stays fixed; one leg drives the knee in toward the chest
    // and back — a real climber alternates legs rapidly, which a single
    // eased cycle approximates well enough for a form reference.
    final shoulder = const Offset(65, 78);
    final hip = const Offset(128, 76);
    final elbow = const Offset(65, 112);
    final head = Offset(shoulder.dx - 16, shoulder.dy - 6);
    final backFoot = const Offset(180, 108);
    final drivingKnee = Offset.lerp(const Offset(155, 100), const Offset(118, 92), progress)!;
    final drivingFoot = Offset.lerp(const Offset(178, 106), const Offset(108, 84), progress)!;

    _limb(canvas, limbPaint, jointPaint, hip, backFoot);
    _limb(canvas, limbPaint, jointPaint, hip, drivingKnee);
    _limb(canvas, limbPaint, jointPaint, drivingKnee, drivingFoot);
    _limb(canvas, limbPaint, jointPaint, shoulder, hip);
    _limb(canvas, limbPaint, jointPaint, shoulder, elbow);
    _head(canvas, jointPaint, head);
  }

  void _paintHipRaise(Canvas canvas, Paint limbPaint, Paint jointPaint) {
    // Lying on the back, shoulders and feet stay grounded; the hips lift
    // and lower (glute bridge / hip thrust).
    const groundY = 112.0;
    final shoulder = const Offset(60, groundY - 6);
    final hip = Offset.lerp(const Offset(115, groundY - 4), const Offset(115, groundY - 34), progress)!;
    final knee = const Offset(150, groundY - 30);
    final foot = const Offset(168, groundY);
    final head = Offset(shoulder.dx - 15, shoulder.dy - 2);

    _limb(canvas, limbPaint, jointPaint, shoulder, hip);
    _limb(canvas, limbPaint, jointPaint, hip, knee);
    _limb(canvas, limbPaint, jointPaint, knee, foot);
    _head(canvas, jointPaint, head);
  }

  @override
  bool shouldRepaint(covariant _FigurePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.motion != motion || oldDelegate.sex != sex;
}
