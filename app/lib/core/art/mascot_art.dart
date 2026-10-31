import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MascotMood {
  /// Attend la réponse : sourire, cligne des yeux.
  idle,

  /// Bonne réponse : grand sourire, bras levés.
  happy,

  /// Mauvaise réponse : petite moue (jamais méchante).
  sad,
}

/// La mascotte de Konoz, dessinée en code : un petit monstre violet aux grands yeux,
/// qui respire doucement, cligne des yeux et réagit aux réponses.
class MascotArt extends StatefulWidget {
  const MascotArt({super.key, required this.size, this.mood = MascotMood.idle});

  /// Largeur du corps ; la hauteur totale fait 1,2 × size.
  final double size;
  final MascotMood mood;

  @override
  State<MascotArt> createState() => _MascotArtState();
}

class _MascotArtState extends State<MascotArt> with SingleTickerProviderStateMixin {
  // Une boucle de 4 s : respiration + un clignement d'yeux vers la fin.
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'الوحش الصغير',
      image: true,
      child: SizedBox(
        width: widget.size * 1.3,
        height: widget.size * 1.2,
        child: CustomPaint(painter: _MascotPainter(widget.mood, _loop)),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.mood, this.loop) : super(repaint: loop);

  final MascotMood mood;
  final Animation<double> loop;

  static const _purple = Color(0xFFA62BA0);
  static const _purpleLight = Color(0xFFC94FC1);
  static const _purpleDark = Color(0xFF7E1C79);
  static const _feather = Color(0xFF5CC8F0);
  static const _featherDark = Color(0xFF2E9FD0);

  @override
  void paint(Canvas canvas, Size box) {
    final v = loop.value;
    final w = box.width / 1.3; // largeur du corps
    final cx = box.width / 2;
    final breath = math.sin(v * math.pi * 2) * .015; // respiration
    final blink = v > .9 && v < .95; // clignement bref

    final bodyTop = box.height * .2;
    final bodyBottom = box.height * .98;
    final bodyH = (bodyBottom - bodyTop) * (1 + breath);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w / 2, bodyBottom - bodyH, cx + w / 2, bodyBottom),
      Radius.circular(w * .26),
    );

    // Ombre au sol
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, bodyBottom), width: w * 1.05, height: w * .1),
        Paint()..color = const Color(0x33000000));

    // Plumes bleues sur la tête
    for (final (dx, ang, len) in [(-.22, -.35, .36), (0.0, 0.0, .42), (.22, .35, .36)]) {
      final base = Offset(cx + dx * w, body.top + w * .05);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(ang + (mood == MascotMood.happy ? math.sin(v * math.pi * 8) * .08 : 0));
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(-w * .06, -w * len, w * .12, w * len), Radius.circular(w * .06));
      canvas.drawRRect(
          r,
          Paint()
            ..shader = const LinearGradient(
                    colors: [_feather, _featherDark], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                .createShader(r.outerRect));
      canvas.restore();
    }

    // Bras (levés quand il est content)
    final armUp = mood == MascotMood.happy;
    for (final side in [-1, 1]) {
      canvas.save();
      canvas.translate(cx + side * w * .47, body.top + bodyH * .55);
      canvas.rotate(side * (armUp ? -2.3 : -.35));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-w * .08, 0, w * .16, w * .32), Radius.circular(w * .08)),
        Paint()..color = _purpleDark,
      );
      canvas.restore();
    }

    // Corps avec relief
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          radius: 1.1,
          colors: [_purpleLight, _purple, _purpleDark],
          stops: [0, .55, 1],
        ).createShader(body.outerRect),
    );
    // Ventre plus clair
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, body.bottom - bodyH * .2), width: w * .62, height: bodyH * .38),
      Paint()..color = const Color(0x33FFFFFF),
    );

    // Yeux
    final eyeY = body.top + bodyH * .32;
    final eyeR = w * .15;
    for (final side in [-1, 1]) {
      final c = Offset(cx + side * w * .19, eyeY);
      if (blink) {
        canvas.drawLine(
            c.translate(-eyeR * .8, 0),
            c.translate(eyeR * .8, 0),
            Paint()
              ..color = Colors.black
              ..strokeWidth = w * .03
              ..strokeCap = StrokeCap.round);
        continue;
      }
      canvas.drawCircle(c, eyeR, Paint()..color = Colors.white);
      canvas.drawCircle(
          c,
          eyeR,
          Paint()
            ..color = _purpleDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * .015);
      final look = switch (mood) {
        MascotMood.happy => const Offset(0, -.25),
        MascotMood.sad => const Offset(0, .3),
        MascotMood.idle => Offset(math.sin(v * math.pi * 2) * .2, 0),
      };
      final pupil = c + look * eyeR;
      canvas.drawCircle(pupil, eyeR * .45, Paint()..color = const Color(0xFF1B1030));
      canvas.drawCircle(pupil + Offset(-eyeR * .15, -eyeR * .18), eyeR * .14, Paint()..color = Colors.white);
      // Sourcils tristes
      if (mood == MascotMood.sad) {
        canvas.drawLine(
            c + Offset(-side * eyeR * .9, -eyeR * 1.35),
            c + Offset(side * eyeR * .5, -eyeR * 1.1),
            Paint()
              ..color = _purpleDark
              ..strokeWidth = w * .035
              ..strokeCap = StrokeCap.round);
      }
    }

    // Joues roses
    for (final side in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + side * w * .33, eyeY + eyeR * 1.35), width: w * .14, height: w * .08),
        Paint()..color = const Color(0x66FF8FB1),
      );
    }

    // Bouche
    final mouthY = eyeY + eyeR * 1.7;
    final mouthW = w * .34;
    switch (mood) {
      case MascotMood.happy:
        final m = Path()
          ..moveTo(cx - mouthW / 2, mouthY)
          ..quadraticBezierTo(cx, mouthY + w * .3, cx + mouthW / 2, mouthY)
          ..close();
        canvas.drawPath(m, Paint()..color = const Color(0xFF4A0E44));
        canvas.save();
        canvas.clipPath(m);
        canvas.drawCircle(Offset(cx, mouthY + w * .2), w * .1, Paint()..color = const Color(0xFFFF6B8A)); // langue
        canvas.restore();
      case MascotMood.sad:
        canvas.drawPath(
          Path()
            ..moveTo(cx - mouthW * .35, mouthY + w * .08)
            ..quadraticBezierTo(cx, mouthY - w * .02, cx + mouthW * .35, mouthY + w * .08),
          Paint()
            ..color = const Color(0xFF4A0E44)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * .035
            ..strokeCap = StrokeCap.round,
        );
      case MascotMood.idle:
        canvas.drawPath(
          Path()
            ..moveTo(cx - mouthW / 2, mouthY)
            ..quadraticBezierTo(cx, mouthY + w * .14, cx + mouthW / 2, mouthY),
          Paint()
            ..color = const Color(0xFF4A0E44)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * .035
            ..strokeCap = StrokeCap.round,
        );
    }

    // Petits crocs
    if (mood != MascotMood.sad) {
      for (final side in [-1, 1]) {
        final x = cx + side * mouthW * .3;
        canvas.drawPath(
          Path()
            ..moveTo(x - w * .03, mouthY + w * .01)
            ..lineTo(x + w * .03, mouthY + w * .01)
            ..lineTo(x, mouthY + w * .08)
            ..close(),
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.mood != mood;
}
