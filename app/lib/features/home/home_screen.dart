import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../map/map_screen.dart';
import 'install_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // l'écran est toujours rempli, quel que soit le contenu
        children: [
          const Positioned.fill(child: GameBackground(asset: AssetPaths.home, scene: SceneTheme.forestDay)),
          SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              final h = c.maxHeight;
              final mascot = math.min(170.0, h * .24);
              return Column(
                children: [
                  SizedBox(height: h * .07),
                  OutlinedTitle('كنوز', size: math.min(88, h * .12)),
                  const OutlinedTitle('مسابقة المسلم الصغير', size: 24, outline: Color(0xFF5B1259)),
                  const Spacer(),
                  _Bouncing(child: Mascot(size: mascot, mood: MascotMood.happy)),
                  const Spacer(),
                  PlayButton(
                    label: 'ابدأ اللعب',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapScreen())),
                  ),
                  const SizedBox(height: 14),
                  const InstallButton(), // visible seulement dans un navigateur qui permet l'installation
                  SizedBox(height: h * .05),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Gros bouton jaune « jouer », qui pulse doucement pour attirer l'œil.
class PlayButton extends StatefulWidget {
  const PlayButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(
            scale: _pressed ? .94 : 1 + Curves.easeInOut.transform(_pulse.value) * .05,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(52, 10, 52, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE77F), Color(0xFFFFC21F), Color(0xFFF29A0E)],
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white, width: 5),
              boxShadow: const [
                BoxShadow(color: Color(0xFFB8650A), offset: Offset(0, 7)),
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 10)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // se réduit si la place manque (petit écran, grande taille de police système)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.label,
                        style: const TextStyle(fontFamily: kDisplayFont, fontSize: 34, color: AppColors.darkBrown)),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.play_arrow_rounded, size: 40, color: AppColors.darkBrown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fait sautiller doucement son contenu.
class _Bouncing extends StatefulWidget {
  const _Bouncing({required this.child});
  final Widget child;

  @override
  State<_Bouncing> createState() => _BouncingState();
}

class _BouncingState extends State<_Bouncing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, -14 * Curves.easeOut.transform(_c.value)), child: child),
        child: widget.child,
      );
}
