import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pièce d'or du jeu (bord, anneau, étoile au centre) : remplace l'icône « $ ».
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: const CustomPaint(painter: _CoinPainter()));
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    canvas.drawCircle(c.translate(0, r * .08), r, Paint()..color = const Color(0xFFB8650A)); // tranche
    canvas.drawCircle(
      c,
      r * .95,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Color(0xFFFFF1A8), Color(0xFFFFC928), Color(0xFFF2A81D)],
          stops: [0, .55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * .7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .1
        ..color = const Color(0xFFE09A12),
    );
    // Étoile à 5 branches
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r * .42 : r * .18;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = const Color(0xFFE09A12));
    // Reflet
    canvas.drawCircle(c + Offset(-r * .4, -r * .42), r * .12, Paint()..color = const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
