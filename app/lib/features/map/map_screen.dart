import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/art/terrain.dart';
import '../../core/assets.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../quiz/quiz_screen.dart';

/// خريطة المستويات: طريق متعرّج عمودي من الأسفل إلى الأعلى.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mapDataProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFC9733A),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تعذّر تحميل الخريطة', style: TextStyle(fontSize: 22, color: Colors.white)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(mapDataProvider), child: const Text('إعادة المحاولة')),
          ]),
        ),
        data: (map) => Stack(
          children: [
            Positioned.fill(child: _MapCanvas(map: map)),
            Positioned(top: 0, left: 0, right: 0, child: _TopBar(map: map)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.map});
  final MapData map;

  @override
  Widget build(BuildContext context) {
    // Bandeau dégradé : la barre reste lisible quand des décors passent dessous.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Row(
            children: [
              // RTL: العدّاد يميناً، الشريط في الوسط، زر الرئيسية يساراً (كما في التصميم)
              CoinCounter(coins: map.coins),
              const SizedBox(width: 10),
              Expanded(child: StripedProgressBar(value: map.globalProgress, height: 30)),
              const SizedBox(width: 10),
              RoundIconButton(icon: Icons.home_rounded, onTap: () => Navigator.of(context).maybePop()),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════ لوحة الخريطة ═══════════════════════════
class _MapCanvas extends StatefulWidget {
  const _MapCanvas({required this.map});
  final MapData map;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  static const _spacing = 135.0; // المسافة العمودية بين مستويين
  static const _topPad = 190.0;
  static const _bottomPad = 150.0;
  static const _node = 76.0;

  final _scroll = ScrollController();
  bool _didScroll = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _height(int n) => _topPad + _bottomPad + math.max(0, n - 1) * _spacing;

  /// موقع المستوى i على الطريق المتعرّج.
  Offset _point(int i, double w, double h) =>
      Offset(w / 2 + math.sin(i * 1.15) * w * .27, h - _bottomPad - i * _spacing);

  /// التمرير تلقائياً إلى المستوى الحالي عند الفتح.
  void _scrollToCurrent(double h, double viewport) {
    if (_didScroll || !_scroll.hasClients) return;
    _didScroll = true;
    final y = h - _bottomPad - widget.map.currentIndex * _spacing;
    // reverse: true ← الإزاحة 0 = أسفل الخريطة
    final target = (h - y) - viewport / 2;
    _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.map;
    final levels = map.levels;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = math.max(_height(levels.length), c.maxHeight);
      final points = [for (var i = 0; i < levels.length; i++) _point(i, w, h)];
      final current = map.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(h, c.maxHeight));

      return SingleChildScrollView(
        controller: _scroll,
        reverse: true, // نبدأ من الأسفل (المستوى 1)
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // خلفية كل عالم في شريط خاص به
              ..._worldBands(map, points, w, h),
              // الطريق
              Positioned.fill(child: CustomPaint(painter: _RoadPainter(points))),
              // المستويات
              for (var i = 0; i < levels.length; i++)
                Positioned(
                  left: points[i].dx - _node / 2,
                  top: points[i].dy - _node / 2,
                  child: _LevelNode(
                    level: levels[i],
                    stars: map.starsOf(levels[i].id),
                    unlocked: map.isUnlocked(i),
                    size: _node,
                    onTap: () => _open(context, map, levels[i], i),
                  ),
                ),
              // علامة الشخصية بجانب المستوى الحالي، نحو وسط الشاشة حتى لا تغطّي المستوى التالي
              if (levels.isNotEmpty)
                Positioned(
                  left: points[current].dx > w / 2
                      ? points[current].dx - _node / 2 - _MascotPin.width + 6
                      : points[current].dx + _node / 2 - 6,
                  top: points[current].dy - _MascotPin.height + 10,
                  child: const _MascotPin(),
                ),
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _worldBands(MapData map, List<Offset> points, double w, double h) {
    final bands = <Widget>[];
    var start = 0;
    for (var i = 1; i <= map.levels.length; i++) {
      final endOfRun = i == map.levels.length || map.levels[i].worldId != map.levels[start].worldId;
      if (!endOfRun) continue;
      final world = map.worldOf(map.levels[start]);
      final bottom = start == 0 ? h : points[start].dy + _spacing / 2;
      final top = i == map.levels.length ? 0.0 : points[i - 1].dy - _spacing / 2;
      bands.add(Positioned(
        left: 0,
        width: w,
        top: top,
        height: bottom - top,
        // Illustration du monde si elle est fournie, sinon terrain dessiné (prairie, nuit, désert)
        child: AppAssets.has(world.mapBackground)
            ? Image.asset(world.mapBackground, fit: BoxFit.cover)
            : CustomPaint(painter: TerrainPainter(sceneForWorld(world.id), seed: world.id * 31 + start)),
      ));
      start = i;
    }
    return bands;
  }

  void _open(BuildContext context, MapData map, Level level, int index) {
    if (!map.isUnlocked(index)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('أكمل المستوى السابق أولاً لفتح هذا المستوى')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizScreen(level: level, world: map.worldOf(level), startCoins: map.coins),
    ));
  }
}

/// يرسم الطريق الرملي بمنحنيات ناعمة (Catmull-Rom → Bézier).
class _RoadPainter extends CustomPainter {
  _RoadPainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, size.height);
    path.lineTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    path.lineTo(points.last.dx, 0);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(
          path,
          stroke
            ..color = const Color(0x55000000)
            ..strokeWidth = 62)
      ..drawPath(
          path,
          stroke
            ..color = const Color(0xFFE8C98F)
            ..strokeWidth = 54)
      ..drawPath(
          path,
          stroke
            ..color = const Color(0xFFF7E3B5)
            ..strokeWidth = 40);

    // نقاط صغيرة على الرمل
    final dots = Paint()..color = const Color(0xFFD9B57A);
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 26) {
        final t = metric.getTangentForOffset(d);
        if (t == null) continue;
        final side = (d ~/ 26).isEven ? 1 : -1;
        // نقطة على يمين الطريق أو يساره بالتناوب (عمودياً على اتجاهه)
        final normal = Offset(-t.vector.dy, t.vector.dx);
        canvas.drawCircle(t.position + normal * (side * 12.0), 2.5, dots);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.points != points;
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.size,
    required this.onTap,
  });

  final Level level;
  final int stars;
  final bool unlocked;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        unlocked ? const [Color(0xFF8BE8FF), Color(0xFF1BA3D6)] : const [Color(0xFFA9B0B8), Color(0xFF5D646C)];

    return Semantics(
      button: true,
      label: 'المستوى ${level.number}${unlocked ? '، $stars نجوم' : '، مقفل'}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // قاعدة الزر (ظلّ داكن أسفله ليبدو بارزاً)
              Positioned(
                top: 8,
                child: Container(
                  width: size,
                  height: size * .9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked ? const Color(0xFF0E5E86) : const Color(0xFF3B4046),
                  ),
                ),
              ),
              Container(
                width: size,
                height: size * .9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: colors, center: const Alignment(-.3, -.5)),
                  border: Border.all(color: Colors.white.withValues(alpha: .8), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${level.number}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x88000000), offset: Offset(0, 2))],
                  ),
                ),
              ),
              if (unlocked && stars > 0) Positioned(top: -size * .42, child: StarRow(stars: stars, size: size * .4)),
              if (!unlocked)
                const Positioned(
                  bottom: -6,
                  child: Icon(Icons.lock_rounded,
                      color: Colors.white, size: 22, shadows: [Shadow(color: Colors.black54, blurRadius: 3)]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دبّوس الشخصية الذي يتمايل فوق المستوى الحالي.
class _MascotPin extends StatefulWidget {
  const _MascotPin();

  static const width = 84.0;
  static const height = 96.0; // الدائرة 84 + الرأس 12

  @override
  State<_MascotPin> createState() => _MascotPinState();
}

class _MascotPinState extends State<_MascotPin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)), child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                border: Border.all(color: const Color(0xFFE4E4E4), width: 2),
              ),
              child: const FittedBox(child: Mascot(size: 60)),
            ),
            CustomPaint(size: const Size(20, 12), painter: _PinTip()),
          ],
        ),
      ),
    );
  }
}

class _PinTip extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
