import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pluie de confettis jouée une fois à chaque nouvelle valeur de [trigger].
/// Ne capte jamais les touchers, et ne joue rien si l'appareil demande moins d'animations.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.trigger, this.count = 46});

  /// Incrémenter pour lancer une nouvelle pluie (0 = aucune).
  final int trigger;
  final int count;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  _Piece(math.Random r)
      : angle = -math.pi / 2 + (r.nextDouble() - .5) * 2.2,
        speed = .55 + r.nextDouble() * .65,
        spin = (r.nextDouble() - .5) * 14,
        size = 6 + r.nextDouble() * 6,
        color = _colors[r.nextInt(_colors.length)],
        round = r.nextBool();

  static const _colors = [
    Color(0xFFFF6B9A),
    Color(0xFFFFD43B),
    Color(0xFF51CF66),
    Color(0xFF4DABF7),
    Color(0xFFB197FC),
    Color(0xFFFF922B),
  ];

  final double angle, speed, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  List<_Piece> _pieces = const [];

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) _play();
  }

  @override
  void initState() {
    super.initState();
    if (widget.trigger > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return;
    final r = math.Random();
    setState(() => _pieces = List.generate(widget.count, (_) => _Piece(r)));
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _ConfettiPainter(_pieces, _c), size: Size.infinite),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t) : super(repaint: t);
  final List<_Piece> pieces;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size s) {
    final v = t.value;
    if (v == 0 || v == 1) return;
    final origin = Offset(s.width / 2, s.height * .45);
    final fade = v < .75 ? 1.0 : (1 - v) / .25;
    for (final p in pieces) {
      final dist = p.speed * s.height * .7 * v;
      final pos = origin + Offset.fromDirection(p.angle, dist) + Offset(0, s.height * .9 * v * v); // gravité
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * v);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * .5), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.pieces != pieces;
}
