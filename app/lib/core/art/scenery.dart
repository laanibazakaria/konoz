import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Les trois univers du jeu ; chaque monde (table `worlds`) en reçoit un.
enum SceneTheme { forestDay, jungleNight, desert }

SceneTheme sceneForWorld(int worldId) => SceneTheme.values[(worldId - 1) % SceneTheme.values.length];

/// Décor animé dessiné en code : ciel, astre, nuages ou étoiles, collines, arbres.
/// Les nuages dérivent lentement et les étoiles scintillent ; tout s'arrête si
/// l'appareil demande moins d'animations.
class Scenery extends StatefulWidget {
  const Scenery({super.key, required this.theme});
  final SceneTheme theme;

  @override
  State<Scenery> createState() => _SceneryState();
}

class _SceneryState extends State<Scenery> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: ScenePainter(widget.theme, _t), size: Size.infinite),
    );
  }
}

class ScenePainter extends CustomPainter {
  ScenePainter(this.theme, this.time) : super(repaint: time);

  final SceneTheme theme;
  final Animation<double> time;

  double get t => time.value;

  @override
  void paint(Canvas canvas, Size size) {
    switch (theme) {
      case SceneTheme.forestDay:
        _forest(canvas, size);
      case SceneTheme.jungleNight:
        _night(canvas, size);
      case SceneTheme.desert:
        _desert(canvas, size);
    }
  }

  // ───────────────────────── Forêt de jour ─────────────────────────
  void _forest(Canvas c, Size s) {
    _sky(c, s, const [Color(0xFF3CC8F0), Color(0xFF9FE6FA)]);
    _sun(c, Offset(s.width * .84, s.height * .1), s.width * .09);
    _clouds(c, s, count: 4, speed: 1);
    _hill(c, s, base: .66, amp: .035, freq: 1.3, phase: .4, color: const Color(0xFFA6DE7C));
    for (final (x, k) in [(.08, 1.0), (.2, .8), (.74, .9), (.9, 1.1)]) {
      _pine(c, Offset(s.width * x, s.height * .7), s.width * .09 * k);
    }
    _hill(c, s, base: .76, amp: .03, freq: 1.8, phase: 1.7, color: const Color(0xFF6CCB52));
    for (final (x, k) in [(.03, 1.3), (.95, 1.4)]) {
      _pine(c, Offset(s.width * x, s.height * .8), s.width * .1 * k);
    }
    _ground(c, s, .86, const Color(0xFF5DBB45));
    _flowers(c, s);
  }

  // ───────────────────────── Jungle de nuit ─────────────────────────
  void _night(Canvas c, Size s) {
    _sky(c, s, const [Color(0xFF0E2140), Color(0xFF1C5868)]);
    _stars(c, s);
    _moon(c, Offset(s.width * .8, s.height * .11), s.width * .075);
    _hill(c, s, base: .66, amp: .04, freq: 1.2, phase: .9, color: const Color(0xFF1D4C5A));
    for (final (x, k, lean) in [(.1, 1.0, -.15), (.86, 1.15, .2), (.62, .75, .1)]) {
      _palm(c, Offset(s.width * x, s.height * .72), s.width * .24 * k, lean, const Color(0xFF2A6470));
    }
    _hill(c, s, base: .78, amp: .03, freq: 1.6, phase: 2.4, color: const Color(0xFF173F45));
    _ground(c, s, .87, const Color(0xFF16383A));
    _fireflies(c, s);
  }

  // ───────────────────────── Désert ─────────────────────────
  void _desert(Canvas c, Size s) {
    _sky(c, s, const [Color(0xFF5EC7F2), Color(0xFFFDE7B5)]);
    _sun(c, Offset(s.width * .2, s.height * .1), s.width * .1);
    _clouds(c, s, count: 2, speed: .6);
    _hill(c, s, base: .67, amp: .045, freq: .9, phase: 2.1, color: const Color(0xFFF6D28A));
    _cactus(c, Offset(s.width * .82, s.height * .72), s.width * .11);
    _hill(c, s, base: .77, amp: .04, freq: 1.4, phase: .3, color: const Color(0xFFEDB95E));
    _cactus(c, Offset(s.width * .1, s.height * .82), s.width * .14);
    _ground(c, s, .87, const Color(0xFFE2A24A));
    _pebbles(c, s);
  }

  // ───────────────────────── Éléments ─────────────────────────
  void _sky(Canvas c, Size s, List<Color> colors) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)
            .createShader(Offset.zero & s),
    );
  }

  void _sun(Canvas c, Offset center, double r) {
    c.drawCircle(center, r * 2.2, Paint()..color = const Color(0x33FFF3A0));
    c.drawCircle(center, r * 1.5, Paint()..color = const Color(0x55FFE97A));
    // rayons qui tournent doucement
    final rays = Paint()
      ..color = const Color(0x88FFD84A)
      ..strokeWidth = r * .18
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 + t * math.pi * 2;
      c.drawLine(center + Offset.fromDirection(a, r * 1.25), center + Offset.fromDirection(a, r * 1.7), rays);
    }
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFFFC928)])
            .createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  void _moon(Canvas c, Offset center, double r) {
    c.drawCircle(center, r * 2, Paint()..color = const Color(0x22FFF4C2));
    c.drawCircle(center, r, Paint()..color = const Color(0xFFFFF4C2));
    final crater = Paint()..color = const Color(0xFFEFE0A6);
    c.drawCircle(center + Offset(-r * .3, -r * .2), r * .22, crater);
    c.drawCircle(center + Offset(r * .35, r * .3), r * .15, crater);
  }

  void _clouds(Canvas c, Size s, {required int count, required double speed}) {
    final p = Paint()..color = Colors.white.withValues(alpha: .92);
    for (var i = 0; i < count; i++) {
      final scale = s.width * (.07 + (i % 3) * .02);
      final span = s.width + scale * 8;
      final x = ((i * .37 + t * speed * (1 + i * .15)) % 1) * span - scale * 4;
      final y = s.height * (.08 + (i % 3) * .09);
      for (final (dx, dy, r) in [(0.0, 0.0, 1.0), (1.1, .25, .8), (-1.0, .3, .75), (.4, -.45, .8)]) {
        c.drawCircle(Offset(x + dx * scale, y + dy * scale), r * scale, p);
      }
    }
  }

  void _stars(Canvas c, Size s) {
    final rnd = math.Random(3);
    for (var i = 0; i < 40; i++) {
      final pos = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * .55);
      final phase = rnd.nextDouble();
      final twinkle = .45 + .55 * (.5 + .5 * math.sin((t * 12 + phase) * math.pi * 2));
      c.drawCircle(pos, 1 + rnd.nextDouble() * 1.8, Paint()..color = Colors.white.withValues(alpha: twinkle));
    }
  }

  void _fireflies(Canvas c, Size s) {
    final rnd = math.Random(9);
    for (var i = 0; i < 9; i++) {
      final bx = rnd.nextDouble(), by = .6 + rnd.nextDouble() * .3, ph = rnd.nextDouble() * math.pi * 2;
      final pos = Offset(
        s.width * (bx + .03 * math.sin(t * math.pi * 2 * 6 + ph)),
        s.height * (by + .02 * math.cos(t * math.pi * 2 * 5 + ph)),
      );
      final glow = .5 + .5 * math.sin(t * math.pi * 2 * 10 + ph);
      c.drawCircle(pos, 6, Paint()..color = const Color(0xFFE8FF7A).withValues(alpha: .25 * glow));
      c.drawCircle(pos, 2.2, Paint()..color = const Color(0xFFF4FFB0).withValues(alpha: .6 + .4 * glow));
    }
  }

  void _hill(Canvas c, Size s,
      {required double base, required double amp, required double freq, required double phase, required Color color}) {
    final path = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width; x += 6) {
      final y = s.height * (base + amp * math.sin(x / s.width * math.pi * 2 * freq + phase));
      path.lineTo(x, y);
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(path, Paint()..color = color);
  }

  void _ground(Canvas c, Size s, double top, Color color) {
    c.drawRect(Rect.fromLTRB(0, s.height * top, s.width, s.height), Paint()..color = color);
  }

  void _pine(Canvas c, Offset foot, double w) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: foot.translate(0, -w * .25), width: w * .18, height: w * .5),
          Radius.circular(w * .05)),
      Paint()..color = const Color(0xFF8B5A2B),
    );
    const greens = [Color(0xFF2E9E44), Color(0xFF37B24D), Color(0xFF51CF66)];
    for (var i = 0; i < 3; i++) {
      final top = foot.dy - w * (1.0 + i * .45);
      final half = w * (.62 - i * .12);
      final baseY = top + w * .85;
      c.drawPath(
        Path()
          ..moveTo(foot.dx, top)
          ..quadraticBezierTo(foot.dx + half * .5, baseY - w * .3, foot.dx + half, baseY)
          ..quadraticBezierTo(foot.dx, baseY + w * .12, foot.dx - half, baseY)
          ..quadraticBezierTo(foot.dx - half * .5, baseY - w * .3, foot.dx, top)
          ..close(),
        Paint()..color = greens[i],
      );
    }
  }

  void _palm(Canvas c, Offset foot, double h, double lean, Color color) {
    final top = foot + Offset(h * lean, -h);
    c.drawPath(
      Path()
        ..moveTo(foot.dx - h * .05, foot.dy)
        ..quadraticBezierTo(foot.dx + h * lean * .2, foot.dy - h * .5, top.dx - h * .025, top.dy)
        ..lineTo(top.dx + h * .025, top.dy)
        ..quadraticBezierTo(foot.dx + h * lean * .2 + h * .06, foot.dy - h * .5, foot.dx + h * .05, foot.dy)
        ..close(),
      Paint()..color = color,
    );
    final leaf = Paint()..color = color;
    for (final a in [-2.8, -2.2, -1.57, -.9, -.35]) {
      final tip = top + Offset.fromDirection(a, h * .45) + Offset(0, h * .12);
      final mid = top + Offset.fromDirection(a, h * .25) + Offset(0, -h * .06);
      final n = Offset.fromDirection(a + math.pi / 2, h * .06);
      c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, top.dx, top.dy),
        leaf,
      );
    }
  }

  void _cactus(Canvas c, Offset foot, double h) {
    const green = Color(0xFF3FA34D), dark = Color(0xFF2F8A3C);
    RRect bar(double cx, double top, double bottom, double w) =>
        RRect.fromRectAndRadius(Rect.fromLTRB(cx - w / 2, top, cx + w / 2, bottom), Radius.circular(w / 2));
    final p = Paint()..color = green;
    final w = h * .26;
    c
      ..drawRRect(bar(foot.dx, foot.dy - h, foot.dy, w), p)
      // bras gauche et droit
      ..drawRRect(bar(foot.dx - w * 1.1, foot.dy - h * .75, foot.dy - h * .35, w * .75), p)
      ..drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(foot.dx - w * 1.1, foot.dy - h * .45, foot.dx, foot.dy - h * .3), Radius.circular(w * .3)),
          p)
      ..drawRRect(bar(foot.dx + w * 1.05, foot.dy - h * .9, foot.dy - h * .5, w * .7), p)
      ..drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(foot.dx, foot.dy - h * .62, foot.dx + w * 1.05, foot.dy - h * .48),
              Radius.circular(w * .3)),
          p);
    final stripe = Paint()
      ..color = dark
      ..strokeWidth = w * .08
      ..strokeCap = StrokeCap.round;
    for (final dx in [-.2, .2]) {
      c.drawLine(Offset(foot.dx + w * dx, foot.dy - h * .9), Offset(foot.dx + w * dx, foot.dy - h * .1), stripe);
    }
  }

  void _flowers(Canvas c, Size s) {
    final rnd = math.Random(5);
    const colors = [Color(0xFFFF6B9A), Color(0xFFFFD43B), Color(0xFFFFFFFF), Color(0xFFB197FC)];
    for (var i = 0; i < 14; i++) {
      final pos = Offset(rnd.nextDouble() * s.width, s.height * (.88 + rnd.nextDouble() * .1));
      final col = colors[i % colors.length];
      for (var k = 0; k < 5; k++) {
        c.drawCircle(pos + Offset.fromDirection(k * math.pi * 2 / 5, 3.2), 2.6, Paint()..color = col);
      }
      c.drawCircle(pos, 2, Paint()..color = const Color(0xFFFFA94D));
    }
  }

  void _pebbles(Canvas c, Size s) {
    final rnd = math.Random(8);
    for (var i = 0; i < 12; i++) {
      final pos = Offset(rnd.nextDouble() * s.width, s.height * (.89 + rnd.nextDouble() * .09));
      c.drawOval(Rect.fromCenter(center: pos, width: 8 + rnd.nextDouble() * 10, height: 5 + rnd.nextDouble() * 4),
          Paint()..color = const Color(0xFFC98A3A));
    }
  }

  @override
  bool shouldRepaint(ScenePainter old) => old.theme != theme;
}
