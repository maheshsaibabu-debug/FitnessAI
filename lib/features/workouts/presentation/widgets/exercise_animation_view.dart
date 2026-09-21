import 'dart:math' as math;

import 'package:flutter/material.dart';

enum StickFigureSex { male, female, other }

enum _Motion {
  pushUp,
  squat,
  plank,
  pullUp,
  mountainClimber,
  hipRaise,
  kettlebellSwing,
  jumpingJack,
  highKnees,
  hangingKneeRaise,
  row,
  calfRaise,
  stride,
  catCow,
}

/// A small set of procedurally-animated exercise illustrations, one per
/// motion pattern, styled as a clean outlined vector figure (thin black
/// contour, minimal fill, gray shorts, a colored shoe accent) rather than
/// a thick-stroke stick figure — matching common fitness-app reference
/// art. Still entirely original vector drawing, not sourced media: real
/// photo/video exercise demonstrations need licensed assets this project
/// doesn't have, and no free exercise-media dataset turned out to be
/// both true 360°-rotatable and safe to bundle/redistribute (checked
/// wger.de, free-exercise-db, ExerciseDB, API-Ninjas — see commit
/// history). Anything not in [_motionFor] falls back to
/// [_UnavailableDemo], which is honest about not having one.
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
    'kettlebell-swing': _Motion.kettlebellSwing,
    'jumping-jacks': _Motion.jumpingJack,
    'high-knees': _Motion.highKnees,
    'squat-jump': _Motion.squat,
    'burpee': _Motion.squat,
    'hanging-knee-raise': _Motion.hangingKneeRaise,
    'bodyweight-row': _Motion.row,
    'calf-raise': _Motion.calfRaise,
    'walking': _Motion.stride,
    'jogging': _Motion.stride,
    'cycling': _Motion.stride,
    'cat-cow': _Motion.catCow,
    'worlds-greatest-stretch': _Motion.squat,
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
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _eased,
        builder: (context, _) => CustomPaint(
          size: const Size(double.infinity, 200),
          painter: _FigurePainter(progress: _eased.value, motion: motion, sex: widget.sex),
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

/// Draws an outlined vector figure — tapered rounded-capsule limbs (a
/// real body contour, not a uniform-width line), a gray shorts block, a
/// female sports-bra overlay, and simple shoes with a colored sole
/// accent, deliberately close to the reference "how-to" illustration
/// style used across mainstream fitness apps.
class _FigurePainter extends CustomPainter {
  _FigurePainter({required this.progress, required this.motion, required this.sex});

  final double progress; // 0..1, eased, oscillates via CurvedAnimation(reverse)
  final _Motion motion;
  final StickFigureSex sex;

  static const _outline = Colors.black;
  static const _skin = Colors.white;
  static const _shortsColor = Color(0xFF8A8A8E);
  static const _accent = Color(0xFF3D6BFF);
  static const _strokeWidth = 2.6;

  // static so these allocate once for the widget's lifetime rather than
  // once per animation frame — AnimatedBuilder constructs a fresh
  // _FigurePainter every tick, so instance-level `late final` Paints
  // were being rebuilt ~60 times/sec for no reason.
  static final Paint _strokePaint = Paint()
    ..color = _outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  static final Paint _skinFill = Paint()
    ..color = _skin
    ..style = PaintingStyle.fill;
  static final Paint _shortsFill = Paint()
    ..color = _shortsColor
    ..style = PaintingStyle.fill;
  static final Paint _accentFill = Paint()
    ..color = _accent
    ..style = PaintingStyle.fill;
  static final Paint _groundPaint = Paint()
    ..color = const Color(0x33000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    const localWidth = 200.0;
    const localHeight = 160.0;
    final scale = math.min(size.width / localWidth, size.height / localHeight);
    canvas.translate(
      (size.width - localWidth * scale) / 2,
      (size.height - localHeight * scale) / 2,
    );
    canvas.scale(scale);

    switch (motion) {
      case _Motion.pushUp:
        _groundLine(canvas, 132);
        _paintPushUp(canvas);
      case _Motion.squat:
        _groundLine(canvas, 138);
        _paintSquat(canvas);
      case _Motion.plank:
        _groundLine(canvas, 122);
        _paintPlank(canvas);
      case _Motion.pullUp:
        _paintPullUp(canvas);
      case _Motion.mountainClimber:
        _groundLine(canvas, 132);
        _paintMountainClimber(canvas);
      case _Motion.hipRaise:
        _groundLine(canvas, 122);
        _paintHipRaise(canvas);
      case _Motion.kettlebellSwing:
        _groundLine(canvas, 140);
        _paintKettlebellSwing(canvas);
      case _Motion.jumpingJack:
        _groundLine(canvas, 138);
        _paintJumpingJack(canvas);
      case _Motion.highKnees:
        _groundLine(canvas, 138);
        _paintHighKnees(canvas);
      case _Motion.hangingKneeRaise:
        _paintHangingKneeRaise(canvas);
      case _Motion.row:
        _groundLine(canvas, 120);
        _paintRow(canvas);
      case _Motion.calfRaise:
        _groundLine(canvas, 138);
        _paintCalfRaise(canvas);
      case _Motion.stride:
        _groundLine(canvas, 138);
        _paintStride(canvas);
      case _Motion.catCow:
        _groundLine(canvas, 128);
        _paintCatCow(canvas);
    }

    canvas.restore();
  }

  void _groundLine(Canvas canvas, double y) {
    canvas.drawLine(Offset(12, y), Offset(188, y), _groundPaint);
  }

  // --- Rendering primitives -------------------------------------------

  /// A tapered rounded-capsule body segment between two joints, wider at
  /// [widthA] and narrower at [widthB] — this is what makes a limb read
  /// as a real body part instead of a uniform stick.
  ///
  /// The rounded ends are built as explicit sampled arcs rather than
  /// `Path.arcToPoint(clockwise: ...)`, deliberately: `clockwise` is a
  /// screen-absolute flag, but which way a cap needs to bulge to stay
  /// outward-facing depends on the segment's on-screen angle, which
  /// changes every frame as a limb swings through the rep. A fixed
  /// `true` bulges correctly at some angles and inverts (pinches) at
  /// others, which reads as the limb glitching mid-animation rather
  /// than moving smoothly. Sampling the arc from its own center/angle
  /// is correct at every angle by construction, not by luck.
  void _segment(Canvas canvas, Offset a, Offset b, double widthA, double widthB) {
    final delta = b - a;
    final len = delta.distance;
    if (len < 0.01) return;
    final unit = Offset(delta.dx / len, delta.dy / len);
    final normal = Offset(-unit.dy, unit.dx);
    final normalAngle = math.atan2(normal.dy, normal.dx);

    final aLeft = a + normal * (widthA / 2);
    final aRight = a - normal * (widthA / 2);
    final bLeft = b + normal * (widthB / 2);

    final path = Path()
      ..moveTo(aLeft.dx, aLeft.dy)
      ..lineTo(bLeft.dx, bLeft.dy);
    _arcCap(path, center: b, startAngle: normalAngle, radius: widthB / 2); // far cap, bulges toward +unit
    path.lineTo(aRight.dx, aRight.dy);
    _arcCap(path, center: a, startAngle: normalAngle + math.pi, radius: widthA / 2); // near cap, bulges toward -unit
    path.close();

    canvas.drawPath(path, _skinFill);
    canvas.drawPath(path, _strokePaint);
  }

  /// Appends a half-circle arc around [center], starting at [startAngle]
  /// (already on the circle) and sweeping -180° — i.e. through
  /// `startAngle - 90°`, the direction the limb is actually pointing —
  /// back to the diametrically opposite point. See [_segment]'s doc
  /// comment for why this is computed explicitly instead of guessed.
  void _arcCap(Path path, {required Offset center, required double startAngle, required double radius, int steps = 8}) {
    for (var i = 1; i <= steps; i++) {
      final angle = startAngle - math.pi * (i / steps);
      path.lineTo(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
    }
  }

  /// Head as a proper oval with a faint side profile line (brow/nose),
  /// plus a headband for the female figure — the reference art's own
  /// differentiation cue, swapped in from the old ponytail.
  void _head(Canvas canvas, Offset center, {double radius = 14}) {
    final rect = Rect.fromCenter(center: center, width: radius * 1.7, height: radius * 2.1);
    canvas.drawOval(rect, _skinFill);
    canvas.drawOval(rect, _strokePaint);

    final profile = Path()
      ..moveTo(center.dx + radius * 0.7, center.dy - radius * 0.3)
      ..quadraticBezierTo(
        center.dx + radius * 0.95,
        center.dy - radius * 0.05,
        center.dx + radius * 0.65,
        center.dy + radius * 0.35,
      );
    canvas.drawPath(profile, Paint()..color = _outline..style = PaintingStyle.stroke..strokeWidth = 1.4);

    if (sex == StickFigureSex.female) {
      final band = Rect.fromCenter(center: Offset(center.dx, center.dy - radius * 0.55), width: radius * 1.9, height: radius * 0.55);
      canvas.drawArc(band, math.pi, math.pi, true, Paint()..color = const Color(0xFF9AA0A6)..style = PaintingStyle.fill);
      canvas.drawArc(band, math.pi, math.pi, false, _strokePaint);
    }
  }

  /// Gray shorts block straddling the hip, oriented along the hip→leg
  /// direction so it rotates naturally with the body in every pose.
  void _shorts(Canvas canvas, Offset hip, Offset legDirTarget, {double width = 40, double length = 26}) {
    final delta = legDirTarget - hip;
    final len = delta.distance;
    final unit = len < 0.01 ? const Offset(0, 1) : Offset(delta.dx / len, delta.dy / len);
    final normal = Offset(-unit.dy, unit.dx);
    final top = hip - unit * (length * 0.35);
    final bottom = hip + unit * (length * 0.65);

    final topLeft = top + normal * (width / 2);
    final topRight = top - normal * (width / 2);
    final bottomLeft = bottom + normal * (width * 0.42 / 2);
    final bottomRight = bottom - normal * (width * 0.42 / 2);

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    canvas.drawPath(path, _shortsFill);
    canvas.drawPath(path, _strokePaint);
    canvas.drawLine(topLeft, topRight, Paint()..color = Colors.black.withValues(alpha: 0.35)..strokeWidth = 1.4);
  }

  /// Sports-bra overlay for the female figure, oriented along the
  /// shoulder→hip line.
  void _bra(Canvas canvas, Offset shoulder, Offset hip, {double width = 34}) {
    final delta = hip - shoulder;
    final len = delta.distance;
    if (len < 0.01) return;
    final unit = Offset(delta.dx / len, delta.dy / len);
    final normal = Offset(-unit.dy, unit.dx);
    final top = shoulder + unit * (len * 0.12);
    final bottom = shoulder + unit * (len * 0.62);

    final topLeft = top + normal * (width / 2);
    final topRight = top - normal * (width / 2);
    final bottomLeft = bottom + normal * (width * 0.7 / 2);
    final bottomRight = bottom - normal * (width * 0.7 / 2);

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..quadraticBezierTo(shoulder.dx, shoulder.dy + len * 0.35, bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..quadraticBezierTo(shoulder.dx, shoulder.dy + len * 0.35, topRight.dx, topRight.dy)
      ..close();

    canvas.drawPath(path, _accentFill);
    canvas.drawPath(path, _strokePaint);
  }

  /// A simple rounded shoe with a colored sole accent, oriented along
  /// the shin→foot direction so it sits naturally under the ankle.
  void _shoe(Canvas canvas, Offset ankle, Offset direction, {bool pointRight = true}) {
    final facing = pointRight ? 1.0 : -1.0;
    final body = Rect.fromCenter(center: ankle + Offset(6 * facing, 6), width: 26, height: 13);
    final rrect = RRect.fromRectAndRadius(body, const Radius.circular(7));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFEDEFF2)..style = PaintingStyle.fill);
    canvas.drawRRect(rrect, _strokePaint);

    final sole = Rect.fromCenter(center: ankle + Offset(6 * facing, 11), width: 24, height: 5);
    canvas.drawRRect(RRect.fromRectAndRadius(sole, const Radius.circular(3)), _accentFill);
  }

  // --- Motions -----------------------------------------------------------

  void _paintPushUp(Canvas canvas) {
    final drop = math.sin(progress * math.pi) * 14;
    final shoulder = Offset(62, 74 + drop);
    final hip = Offset(126, 68 + drop * 0.6);
    final hand = const Offset(62, 120);
    final foot = const Offset(178, 110);
    final head = Offset(shoulder.dx - 15, shoulder.dy - 10);

    _segment(canvas, hip, foot, 15, 9); // legs
    _segment(canvas, shoulder, hip, 22, 17); // torso
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, hand, 13, 9); // arm
    _shorts(canvas, Offset(hip.dx - 6, hip.dy + 2), foot, width: 22, length: 20);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 18);
    _shoe(canvas, foot, hip);
    _head(canvas, head, radius: 12);
  }

  void _paintSquat(Canvas canvas) {
    final bend = progress; // 0 standing, 1 fully squatted
    final head = Offset(100, 24 + bend * 30);
    final shoulder = Offset(100, 42 + bend * 30);
    final hip = Offset(100, 70 + bend * 30);
    final knee = Offset(100 + bend * 14, 102 + bend * 4);
    final foot = const Offset(100, 132);
    final handY = 36 + bend * 14;

    _segment(canvas, hip, knee, 18, 13);
    _segment(canvas, knee, foot, 13, 9);
    _segment(canvas, shoulder, hip, 24, 19);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, Offset(shoulder.dx - 22, shoulder.dy + handY), 12, 8);
    _segment(canvas, shoulder, Offset(shoulder.dx + 22, shoulder.dy + handY), 12, 8);
    _shorts(canvas, hip, foot, width: 32, length: 24);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 22);
    _shoe(canvas, foot - const Offset(11, 0), hip, pointRight: false);
    _shoe(canvas, foot + const Offset(11, 0), hip);
    _head(canvas, head);
  }

  void _paintPlank(Canvas canvas) {
    final bob = math.sin(progress * math.pi) * 2;
    final shoulder = Offset(62, 82 + bob);
    final hip = Offset(126, 80 + bob);
    final elbow = const Offset(62, 116);
    final foot = const Offset(182, 112);
    final head = Offset(shoulder.dx - 15, shoulder.dy - 8);

    _segment(canvas, hip, foot, 15, 9);
    _segment(canvas, shoulder, hip, 22, 17);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, elbow, 13, 9);
    _shorts(canvas, Offset(hip.dx - 6, hip.dy + 2), foot, width: 22, length: 20);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 18);
    _shoe(canvas, foot, hip);
    _head(canvas, head, radius: 12);
  }

  void _paintPullUp(Canvas canvas) {
    final lift = progress; // 0 hanging, 1 chin over the bar
    final barPaint = Paint()
      ..color = const Color(0xFF6B6B70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const barLeft = Offset(52, 16);
    const barRight = Offset(148, 16);
    final head = Offset(100, 30 + (1 - lift) * 42);
    final shoulder = Offset(100, 48 + (1 - lift) * 42);
    final hip = Offset(100, 88 + (1 - lift) * 30);
    final foot = Offset(100, 130 + (1 - lift) * 6);

    canvas.drawLine(barLeft, barRight, barPaint);
    _segment(canvas, barLeft, shoulder, 10, 13);
    _segment(canvas, barRight, shoulder, 10, 13);
    _segment(canvas, shoulder, hip, 22, 17);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, hip, foot, 15, 9);
    _shorts(canvas, hip, foot, width: 30, length: 22);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 20);
    _shoe(canvas, foot - const Offset(8, 0), hip, pointRight: false);
    _shoe(canvas, foot + const Offset(8, 0), hip);
    _head(canvas, head);
  }

  void _paintMountainClimber(Canvas canvas) {
    final shoulder = const Offset(62, 82);
    final hip = const Offset(126, 80);
    final elbow = const Offset(62, 116);
    final head = Offset(shoulder.dx - 15, shoulder.dy - 8);
    final backFoot = const Offset(182, 112);
    final drivingKnee = Offset.lerp(const Offset(158, 104), const Offset(118, 96), progress)!;
    final drivingFoot = Offset.lerp(const Offset(180, 110), const Offset(106, 88), progress)!;

    _segment(canvas, hip, backFoot, 15, 9);
    _segment(canvas, hip, drivingKnee, 15, 11);
    _segment(canvas, drivingKnee, drivingFoot, 11, 8);
    _segment(canvas, shoulder, hip, 22, 17);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, elbow, 13, 9);
    _shorts(canvas, Offset(hip.dx - 6, hip.dy + 2), backFoot, width: 22, length: 20);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 18);
    _shoe(canvas, backFoot, hip);
    _shoe(canvas, drivingFoot, drivingKnee);
    _head(canvas, head, radius: 12);
  }

  void _paintHipRaise(Canvas canvas) {
    const groundY = 122.0;
    const shoulder = Offset(58, groundY - 6);
    final hip = Offset.lerp(const Offset(114, groundY - 4), const Offset(114, groundY - 34), progress)!;
    const knee = Offset(150, groundY - 30);
    const foot = Offset(168, groundY);
    final head = Offset(shoulder.dx - 15, shoulder.dy - 2);

    _segment(canvas, shoulder, hip, 22, 17);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, hip, knee, 18, 13);
    _segment(canvas, knee, foot, 13, 9);
    _shorts(canvas, hip, knee, width: 30, length: 22);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 20);
    _shoe(canvas, foot, knee);
    _head(canvas, head, radius: 12);
  }

  void _paintKettlebellSwing(Canvas canvas) {
    final swing = progress; // 0 hinged forward (bell low), 1 standing tall (bell chest-height)
    final hipShift = (1 - swing) * 10;
    final head = Offset(100, 26 - swing * 6);
    final shoulder = Offset(100, 44 - swing * 4);
    final hip = Offset(100 + hipShift * 0.4, 78);
    const leftFoot = Offset(84, 140);
    const rightFoot = Offset(116, 140);
    final hand = Offset(100, 58 + (1 - swing) * 52);

    _segment(canvas, hip, leftFoot, 16, 10);
    _segment(canvas, hip, rightFoot, 16, 10);
    _segment(canvas, shoulder, hip, 22, 18);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, hand, 12, 8);
    _shorts(canvas, hip, const Offset(100, 140), width: 34, length: 24);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 22);
    _shoe(canvas, leftFoot, hip, pointRight: false);
    _shoe(canvas, rightFoot, hip);
    _head(canvas, head);
    _kettlebell(canvas, hand);
  }

  void _paintJumpingJack(Canvas canvas) {
    final t = progress; // 0 closed, 1 open
    final head = const Offset(100, 24);
    final shoulder = const Offset(100, 42);
    final hip = const Offset(100, 74);
    final spread = 8 + t * 22;
    final leftFoot = Offset(100 - spread, 138);
    final rightFoot = Offset(100 + spread, 138);
    final leftHand = Offset.lerp(const Offset(78, 86), const Offset(70, 16), t)!;
    final rightHand = Offset.lerp(const Offset(122, 86), const Offset(130, 16), t)!;

    _segment(canvas, hip, leftFoot, 16, 10);
    _segment(canvas, hip, rightFoot, 16, 10);
    _segment(canvas, shoulder, hip, 22, 18);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, leftHand, 12, 8);
    _segment(canvas, shoulder, rightHand, 12, 8);
    _shorts(canvas, hip, const Offset(100, 138), width: 30, length: 22);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 22);
    _shoe(canvas, leftFoot, hip, pointRight: false);
    _shoe(canvas, rightFoot, hip);
    _head(canvas, head);
  }

  void _paintHighKnees(Canvas canvas) {
    final t = progress;
    final head = const Offset(100, 26);
    final shoulder = const Offset(100, 44);
    final hip = const Offset(100, 76);
    const standFoot = Offset(108, 138);
    final drivingKnee = Offset.lerp(const Offset(92, 108), const Offset(88, 62), t)!;
    final drivingFoot = Offset.lerp(const Offset(90, 138), const Offset(78, 86), t)!;
    final leftHand = Offset.lerp(const Offset(122, 70), const Offset(112, 28), t)!;
    final rightHand = Offset.lerp(const Offset(78, 96), const Offset(92, 110), t)!;

    _segment(canvas, hip, standFoot, 16, 10);
    _segment(canvas, hip, drivingKnee, 15, 11);
    _segment(canvas, drivingKnee, drivingFoot, 11, 8);
    _segment(canvas, shoulder, hip, 22, 18);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, leftHand, 12, 8);
    _segment(canvas, shoulder, rightHand, 12, 8);
    _shorts(canvas, hip, standFoot, width: 30, length: 22);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 22);
    _shoe(canvas, standFoot, hip);
    _shoe(canvas, drivingFoot, drivingKnee, pointRight: false);
    _head(canvas, head);
  }

  void _paintHangingKneeRaise(Canvas canvas) {
    final lift = progress; // 0 hanging straight, 1 knees to chest
    final barPaint = Paint()
      ..color = const Color(0xFF6B6B70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const barLeft = Offset(52, 16);
    const barRight = Offset(148, 16);
    const head = Offset(100, 32);
    const shoulder = Offset(100, 50);
    const hip = Offset(100, 90);
    final knee = Offset.lerp(const Offset(100, 126), const Offset(124, 96), lift)!;
    final foot = Offset.lerp(const Offset(100, 152), const Offset(132, 100), lift)!;

    canvas.drawLine(barLeft, barRight, barPaint);
    _segment(canvas, barLeft, shoulder, 10, 13);
    _segment(canvas, barRight, shoulder, 10, 13);
    _segment(canvas, shoulder, hip, 22, 17);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, hip, knee, 16, 11);
    _segment(canvas, knee, foot, 11, 8);
    _shorts(canvas, hip, knee, width: 30, length: 22);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 20);
    _shoe(canvas, foot, knee);
    _head(canvas, head);
  }

  void _paintRow(Canvas canvas) {
    final pull = progress; // 0 arms extended, 1 chest to anchor
    const anchor = Offset(66, 22);
    const hip = Offset(150, 106);
    const foot = Offset(186, 118);
    final shoulder = Offset.lerp(const Offset(102, 62), const Offset(80, 46), pull)!;
    final head = Offset(shoulder.dx - 14, shoulder.dy - 9);

    canvas.drawLine(const Offset(56, 14), const Offset(76, 30), Paint()..color = const Color(0xFF6B6B70)..strokeWidth = 5..strokeCap = StrokeCap.round);
    _segment(canvas, hip, foot, 15, 9);
    _segment(canvas, shoulder, hip, 22, 17);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, anchor, 12, 8);
    _shorts(canvas, Offset(hip.dx - 6, hip.dy + 2), foot, width: 22, length: 20);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 18);
    _shoe(canvas, foot, hip);
    _head(canvas, head, radius: 12);
  }

  void _paintCalfRaise(Canvas canvas) {
    final raise = progress; // 0 heels down, 1 up on toes
    final lift = raise * 7;
    final head = Offset(100, 24 - lift);
    final shoulder = Offset(100, 42 - lift);
    final hip = Offset(100, 74 - lift);
    final knee = Offset(100, 106 - lift);
    final heel = Offset(100, 138 - lift);

    _segment(canvas, hip, knee, 17, 12);
    _segment(canvas, knee, heel, 12, 9);
    _segment(canvas, shoulder, hip, 22, 18);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, Offset(shoulder.dx - 20, shoulder.dy + 40 - lift), 11, 7);
    _segment(canvas, shoulder, Offset(shoulder.dx + 20, shoulder.dy + 40 - lift), 11, 7);
    _shorts(canvas, hip, knee, width: 30, length: 22);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 22);
    _shoe(canvas, heel, knee);
    _head(canvas, head);
  }

  void _paintStride(Canvas canvas) {
    final t = progress;
    const head = Offset(100, 26);
    const shoulder = Offset(100, 46);
    const hip = Offset(100, 78);
    final frontKnee = Offset.lerp(const Offset(108, 104), const Offset(124, 100), t)!;
    final frontFoot = Offset.lerp(const Offset(112, 138), const Offset(136, 128), t)!;
    final backKnee = Offset.lerp(const Offset(92, 104), const Offset(76, 110), t)!;
    final backFoot = Offset.lerp(const Offset(88, 138), const Offset(64, 126), t)!;
    final frontHand = Offset.lerp(const Offset(84, 70), const Offset(70, 58), t)!;
    final backHand = Offset.lerp(const Offset(116, 70), const Offset(128, 88), t)!;

    _segment(canvas, hip, frontKnee, 15, 11);
    _segment(canvas, frontKnee, frontFoot, 11, 8);
    _segment(canvas, hip, backKnee, 15, 11);
    _segment(canvas, backKnee, backFoot, 11, 8);
    _segment(canvas, shoulder, hip, 22, 17);
    _torsoLine(canvas, shoulder, hip);
    _segment(canvas, shoulder, frontHand, 11, 7);
    _segment(canvas, shoulder, backHand, 11, 7);
    _shorts(canvas, hip, frontFoot, width: 30, length: 22);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, hip, width: 22);
    _shoe(canvas, frontFoot, frontKnee);
    _shoe(canvas, backFoot, backKnee, pointRight: false);
    _head(canvas, head);
  }

  void _paintCatCow(Canvas canvas) {
    final arch = progress; // 0 cow (belly sags), 1 cat (back arches up)
    const hand = Offset(64, 128);
    const knee = Offset(146, 128);
    final hip = Offset(140, 100 - arch * 4);
    final shoulder = Offset(70, 92 - (1 - arch) * 4);
    final mid = Offset((hip.dx + shoulder.dx) / 2, (hip.dy + shoulder.dy) / 2 + (arch - 0.5) * 14);
    final head = Offset(shoulder.dx - 8, shoulder.dy - 4 + (1 - arch) * 10);

    _segment(canvas, hand, shoulder, 10, 15);
    _segment(canvas, shoulder, mid, 18, 17);
    _segment(canvas, mid, hip, 17, 18);
    _segment(canvas, hip, knee, 16, 12);
    _shorts(canvas, hip, knee, width: 26, length: 20);
    if (sex == StickFigureSex.female) _bra(canvas, shoulder, mid, width: 20);
    _head(canvas, head, radius: 12);
  }

  /// A faint chest/ab center line on the lower torso — visible below a
  /// female figure's sports bra, full-length on the male figure — the
  /// last detail differentiating "outlined body" from "outlined stick".
  void _torsoLine(Canvas canvas, Offset shoulder, Offset hip) {
    final start = sex == StickFigureSex.female ? Offset.lerp(shoulder, hip, 0.62)! : Offset.lerp(shoulder, hip, 0.28)!;
    canvas.drawLine(start, Offset.lerp(shoulder, hip, 0.92)!, Paint()..color = Colors.black.withValues(alpha: 0.25)..strokeWidth = 1.4);
  }

  /// A simple kettlebell: a filled circle with a small handle arc on top.
  void _kettlebell(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 12, _skinFill);
    canvas.drawCircle(center, 12, _strokePaint);
    final handle = Rect.fromCenter(center: center - const Offset(0, 15), width: 15, height: 11);
    canvas.drawArc(handle, math.pi, math.pi, false, _strokePaint);
  }

  @override
  bool shouldRepaint(covariant _FigurePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.motion != motion || oldDelegate.sex != sex;
}
