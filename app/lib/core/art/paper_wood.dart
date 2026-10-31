import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Parchemin aux bords déchirés (panneau de la question).
class ParchmentPainter extends CustomPainter {
  const ParchmentPainter({this.seed = 1});

  /// Change la forme des déchirures d'une question à l'autre.
  final int seed;

  Path _torn(Size s) {
    final rnd = math.Random(seed);
    double j(double max) => (rnd.nextDouble() - .5) * 2 * max;
    final path = Path()..moveTo(j(3), j(3));
    for (double x = 14; x < s.width; x += 14 + rnd.nextDouble() * 18) {
      path.lineTo(x, j(3));
    }
    path.lineTo(s.width + j(2), j(3));
    for (double y = 12; y < s.height; y += 12 + rnd.nextDouble() * 16) {
      path.lineTo(s.width + j(3.5), y);
    }
    path.lineTo(s.width + j(2), s.height + j(3));
    for (double x = s.width - 10; x > 0; x -= 8 + rnd.nextDouble() * 16) {
      path.lineTo(x, s.height + j(5)); // bas plus déchiré
    }
    path.lineTo(j(2), s.height + j(3));
    for (double y = s.height - 12; y > 0; y -= 12 + rnd.nextDouble() * 16) {
      path.lineTo(j(3.5), y);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size s) {
    final path = _torn(s);
    canvas.drawPath(path.shift(const Offset(0, 7)), Paint()..color = const Color(0xFF6B4A35)); // épaisseur
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF6E8), Color(0xFFF7E3C8), Color(0xFFF1D7B4)],
        ).createShader(Offset.zero & s),
    );
    // Taches et grain du papier
    final rnd = math.Random(seed * 7 + 3);
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
          width: 30 + rnd.nextDouble() * 70,
          height: 12 + rnd.nextDouble() * 30,
        ),
        Paint()..color = const Color(0x0F8B5A2B),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x55B07A45),
    );
  }

  @override
  bool shouldRepaint(ParchmentPainter old) => old.seed != seed;
}

/// Carte de réponse en bois, avec l'encoche en haut comme dans la maquette.
class WoodCardPainter extends CustomPainter {
  const WoodCardPainter({required this.border, this.glow});

  final Color border;

  /// Halo coloré (vert = juste, rouge = faux), null au repos.
  final Color? glow;

  @override
  void paint(Canvas canvas, Size s) {
    final notch = s.width * .07;
    final shape = Path()
      ..moveTo(4, 4)
      ..lineTo(s.width / 2 - notch, 4)
      ..lineTo(s.width / 2, 4 + notch * 1.1)
      ..lineTo(s.width / 2 + notch, 4)
      ..lineTo(s.width - 4, 4)
      ..lineTo(s.width - 4, s.height - 4)
      ..lineTo(4, s.height - 4)
      ..close();

    if (glow != null) {
      canvas.drawPath(
        shape,
        Paint()
          ..color = glow!.withValues(alpha: .8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 14),
      );
    }
    canvas.drawPath(shape.shift(const Offset(0, 6)), Paint()..color = const Color(0x55000000)); // ombre portée

    // Bois
    canvas.drawPath(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAD465), Color(0xFFF4BC3F), Color(0xFFEDA232)],
          stops: [0, .6, 1],
        ).createShader(Offset.zero & s),
    );
    canvas.save();
    canvas.clipPath(shape);
    // Veines du bois
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x40C77A1C);
    for (final f in [.28, .55, .8]) {
      final y = s.height * f;
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..cubicTo(s.width * .3, y - 10, s.width * .6, y + 12, s.width, y - 4),
        grain,
      );
    }
    // Reflet en diagonale
    canvas.drawPath(
      Path()
        ..moveTo(s.width * .08, 0)
        ..lineTo(s.width * .3, 0)
        ..lineTo(s.width * .12, s.height * .45)
        ..lineTo(0, s.height * .45)
        ..close(),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.restore();

    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeJoin = StrokeJoin.round
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(WoodCardPainter old) => old.border != border || old.glow != glow;
}
