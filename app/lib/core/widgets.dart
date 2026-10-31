import 'package:flutter/material.dart';

import 'art/coin.dart';
import 'art/mascot_art.dart';
import 'art/scenery.dart';
import 'assets.dart';
import 'theme.dart';

export 'art/mascot_art.dart' show MascotMood;
export 'art/scenery.dart' show SceneTheme, sceneForWorld;

/// Fond d'écran : l'illustration du monde si elle est fournie, sinon le décor animé dessiné en code.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.asset, required this.scene});
  final String asset;
  final SceneTheme scene;

  @override
  Widget build(BuildContext context) {
    final drawn = Scenery(theme: scene);
    if (!AppAssets.has(asset)) return drawn;
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => drawn,
    );
  }
}

/// Titre ludique : police Lalezar, lettres blanches cernées de violet.
class OutlinedTitle extends StatelessWidget {
  const OutlinedTitle(this.text,
      {super.key, this.size = 40, this.color = Colors.white, this.outline = AppColors.purpleText});
  final String text;
  final double size;
  final Color color;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? fg) => TextStyle(
          fontFamily: kDisplayFont,
          fontSize: size,
          height: 1.25,
          color: fg == null ? color : null,
          foreground: fg,
          shadows: fg == null ? null : [Shadow(color: outline.withValues(alpha: .6), offset: const Offset(0, 4))],
        );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style(Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * .16
            ..strokeJoin = StrokeJoin.round
            ..color = outline),
        ),
        Text(text, textAlign: TextAlign.center, style: style(null)),
      ],
    );
  }
}

/// زرّ دائري أصفر (القائمة، الرئيسية...).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.size = 56});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFFFFE27A), Color(0xFFF2A81D)]),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 3))],
        ),
        child: Icon(icon,
            color: Colors.white,
            size: size * .55,
            shadows: const [Shadow(color: Color(0xFFB0700C), offset: Offset(0, 2))]),
      ),
    );
  }
}

/// فقاعة القطع الزرقاء (أسفل اليمين في شاشة السؤال).
class CoinBubble extends StatelessWidget {
  const CoinBubble({super.key, required this.coins, this.size = 76});
  final int coins;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.lightBlue, AppColors.blue],
          center: Alignment(-.3, -.4),
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
        child: FittedBox(
          key: ValueKey(coins),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '$coins',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: Color(0xFF0B5E80), offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// عدّاد القطع في أعلى الخريطة: أيقونة ذهبية + رقم.
class CoinCounter extends StatelessWidget {
  const CoinCounter({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 26),
          const SizedBox(width: 4),
          Text('$coins',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// شريط التقدّم المخطّط (يُستخدم في الخريطة وفي المستوى).
/// يمتلئ من اليسار إلى اليمين كما في التصميم المرجعي.
class StripedProgressBar extends StatelessWidget {
  const StripedProgressBar({super.key, required this.value, this.height = 26});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF6B4C9A),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE066), Color(0xFFF59E0B)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La mascotte : l'illustration si elle est fournie, sinon la version dessinée et animée.
class Mascot extends StatelessWidget {
  const Mascot({super.key, required this.size, this.mood = MascotMood.idle});
  final double size;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    if (!AppAssets.has(AssetPaths.mascot)) return MascotArt(size: size, mood: mood);
    return Image.asset(AssetPaths.mascot, height: size * 1.2);
  }
}

/// ثلاث نجوم (ذهبية للمكتسبة، رمادية للباقي).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 24});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              // النجمة الوسطى أعلى قليلاً
              padding: EdgeInsets.only(bottom: i == 1 ? size * .3 : 0),
              child: Icon(
                Icons.star_rounded,
                size: size,
                color: i < stars ? AppColors.gold : const Color(0xFFD9D9D9),
                shadows: const [Shadow(color: Color(0xFF9A6A00), offset: Offset(0, 1.5))],
              ),
            ),
        ],
      ),
    );
  }
}
