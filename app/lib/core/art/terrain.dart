import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scenery.dart';

/// Sol de la carte des niveaux pour un monde : couleur de fond, taches de relief
/// et décors (sapins et fleurs, champignons lumineux, cactus et rochers) sur les côtés,
/// en laissant le centre libre pour le chemin.
class TerrainPainter extends CustomPainter {
  const TerrainPainter(this.theme, {this.seed = 1});

  final SceneTheme theme;
  final int seed;

  @override
  void paint(Canvas canvas, Size s) {
    final (base, light, dark) = switch (theme) {
      SceneTheme.forestDay => (const Color(0xFF7DCB55), const Color(0xFF9BDB6E), const Color(0xFF5EAF3F)),
      SceneTheme.jungleNight => (const Color(0xFF7E5E96), const Color(0xFF9676AE), const Color(0xFF5F4476)),
      SceneTheme.desert => (const Color(0xFFF1CF7E), const Color(0xFFF8E2A6), const Color(0xFFE2B45C)),
    };
    canvas.drawRect(Offset.zero & s, Paint()..color = base);

    final rnd = math.Random(seed);
    // Taches claires et sombres pour donner du relief
    for (var i = 0; i < (s.height / 70).ceil(); i++) {
      final c = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 60 + rnd.nextDouble() * 120, height: 30 + rnd.nextDouble() * 50),
        Paint()..color = (rnd.nextBool() ? light : dark).withValues(alpha: .55),
      );
    }

    // Décors sur les bords (le chemin passe au centre)
    final n = (s.height / 110).ceil();
    for (var i = 0; i < n; i++) {
      final left = i.isEven;
      final x = left ? s.width * (.03 + rnd.nextDouble() * .13) : s.width * (.84 + rnd.nextDouble() * .13);
      final pos = Offset(x, (i + rnd.nextDouble()) * s.height / n);
      final k = .8 + rnd.nextDouble() * .5;
      switch (theme) {
        case SceneTheme.forestDay:
          rnd.nextDouble() < .6 ? _pine(canvas, pos, 46 * k) : _bush(canvas, pos, 30 * k);
          if (rnd.nextBool()) _flower(canvas, pos + Offset(left ? 34 : -34, 18), const Color(0xFFFF6B9A));
        case SceneTheme.jungleNight:
          rnd.nextDouble() < .5 ? _mushroom(canvas, pos, 26 * k) : _rock(canvas, pos, 30 * k, const Color(0xFF4E3863));
          if (rnd.nextBool()) _sparkle(canvas, pos + Offset(left ? 30 : -30, -24));
        case SceneTheme.desert:
          rnd.nextDouble() < .55 ? _cactus(canvas, pos, 50 * k) : _rock(canvas, pos, 28 * k, const Color(0xFFC98A3A));
      }
    }
  }

  void _shadow(Canvas c, Offset foot, double w) =>
      c.drawOval(Rect.fromCenter(center: foot, width: w, height: w * .3), Paint()..color = const Color(0x33000000));

  void _pine(Canvas c, Offset foot, double h) {
    _shadow(c, foot, h * .8);
    c.drawRect(Rect.fromCenter(center: foot.translate(0, -h * .1), width: h * .14, height: h * .24),
        Paint()..color = const Color(0xFF8B5A2B));
    const greens = [Color(0xFF2E9E44), Color(0xFF37B24D), Color(0xFF51CF66)];
    for (var i = 0; i < 3; i++) {
      final top = foot.dy - h * (.55 + i * .28);
      final half = h * (.42 - i * .09);
      c.drawPath(
        Path()
          ..moveTo(foot.dx, top - h * .3)
          ..lineTo(foot.dx + half, top + h * .12)
          ..lineTo(foot.dx - half, top + h * .12)
          ..close(),
        Paint()..color = greens[i],
      );
    }
  }

  void _bush(Canvas c, Offset foot, double w) {
    _shadow(c, foot, w * 1.2);
    final p = Paint()..color = const Color(0xFF3FA34D);
    for (final (dx, dy, r) in [(-.3, -.3, .35), (.3, -.3, .35), (0.0, -.55, .4)]) {
      c.drawCircle(foot + Offset(dx * w, dy * w), r * w, p);
    }
    c.drawCircle(foot + Offset(-.1 * w, -.65 * w), .12 * w, Paint()..color = const Color(0x55FFFFFF));
  }

  void _flower(Canvas c, Offset pos, Color col) {
    for (var k = 0; k < 5; k++) {
      c.drawCircle(pos + Offset.fromDirection(k * math.pi * 2 / 5, 4), 3.4, Paint()..color = col);
    }
    c.drawCircle(pos, 2.6, Paint()..color = const Color(0xFFFFD43B));
  }

  void _mushroom(Canvas c, Offset foot, double h) {
    c.drawCircle(foot.translate(0, -h * .6), h * .8, Paint()..color = const Color(0x2299F6E4)); // halo
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: foot.translate(0, -h * .25), width: h * .3, height: h * .5), Radius.circular(h * .1)),
      Paint()..color = const Color(0xFFF1E6FF),
    );
    c.drawPath(
      Path()
        ..moveTo(foot.dx - h * .55, foot.dy - h * .45)
        ..quadraticBezierTo(foot.dx, foot.dy - h * 1.25, foot.dx + h * .55, foot.dy - h * .45)
        ..close(),
      Paint()..color = const Color(0xFF63E6BE),
    );
    for (final dx in [-.2, .18]) {
      c.drawCircle(Offset(foot.dx + dx * h, foot.dy - h * .7), h * .08, Paint()..color = const Color(0xFFE6FCF5));
    }
  }

  void _rock(Canvas c, Offset foot, double w, Color color) {
    _shadow(c, foot, w * 1.1);
    c.drawPath(
      Path()
        ..moveTo(foot.dx - w * .5, foot.dy)
        ..lineTo(foot.dx - w * .35, foot.dy - w * .45)
        ..lineTo(foot.dx + w * .05, foot.dy - w * .6)
        ..lineTo(foot.dx + w * .45, foot.dy - w * .3)
        ..lineTo(foot.dx + w * .5, foot.dy)
        ..close(),
      Paint()..color = color,
    );
    c.drawPath(
      Path()
        ..moveTo(foot.dx - w * .3, foot.dy - w * .4)
        ..lineTo(foot.dx + w * .03, foot.dy - w * .52)
        ..lineTo(foot.dx - w * .05, foot.dy - w * .3)
        ..close(),
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  void _sparkle(Canvas c, Offset p) {
    final paint = Paint()
      ..color = const Color(0xCCFFF3BF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    c
      ..drawLine(p.translate(-6, 0), p.translate(6, 0), paint)
      ..drawLine(p.translate(0, -6), p.translate(0, 6), paint);
  }

  void _cactus(Canvas c, Offset foot, double h) {
    _shadow(c, foot, h * .7);
    const green = Color(0xFF3FA34D);
    final w = h * .26;
    RRect bar(double cx, double top, double bottom, double bw) =>
        RRect.fromRectAndRadius(Rect.fromLTRB(cx - bw / 2, top, cx + bw / 2, bottom), Radius.circular(bw / 2));
    final p = Paint()..color = green;
    c
      ..drawRRect(bar(foot.dx, foot.dy - h, foot.dy, w), p)
      ..drawRRect(bar(foot.dx - w * 1.05, foot.dy - h * .75, foot.dy - h * .38, w * .7), p)
      ..drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(foot.dx - w * 1.05, foot.dy - h * .48, foot.dx, foot.dy - h * .34),
              Radius.circular(w * .3)),
          p)
      ..drawRRect(bar(foot.dx + w * 1.0, foot.dy - h * .88, foot.dy - h * .52, w * .65), p)
      ..drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(foot.dx, foot.dy - h * .64, foot.dx + w, foot.dy - h * .5), Radius.circular(w * .3)),
          p);
    c.drawLine(
        Offset(foot.dx, foot.dy - h * .9),
        Offset(foot.dx, foot.dy - h * .1),
        Paint()
          ..color = const Color(0xFF2F8A3C)
          ..strokeWidth = w * .1
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(TerrainPainter old) => old.theme != theme || old.seed != seed;
}
