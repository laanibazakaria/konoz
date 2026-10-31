import 'package:flutter/material.dart';

import '../../core/install/install.dart';
import '../../core/theme.dart';

/// Bouton « ثبّت التطبيق على هاتفك » de l'écran d'accueil.
/// - Chrome / Edge : ouvre la fenêtre d'installation du navigateur.
/// - iPhone : explique les 3 gestes dans Safari.
/// - Déjà installée ou app native : n'affiche rien.
class InstallButton extends StatefulWidget {
  const InstallButton({super.key, this.stateOverride});

  /// Pour les tests uniquement.
  final InstallState? stateOverride;

  @override
  State<InstallButton> createState() => _InstallButtonState();
}

class _InstallButtonState extends State<InstallButton> {
  late InstallState _state = widget.stateOverride ?? currentInstallState();

  @override
  void initState() {
    super.initState();
    // Chrome peut proposer l'installation quelques secondes après le chargement.
    if (widget.stateOverride == null) onInstallChange(_refresh);
  }

  @override
  void didUpdateWidget(InstallButton old) {
    super.didUpdateWidget(old);
    if (widget.stateOverride != old.stateOverride) _state = widget.stateOverride ?? currentInstallState();
  }

  void _refresh() {
    if (mounted) setState(() => _state = currentInstallState());
  }

  Future<void> _onTap() async {
    if (_state == InstallState.ios) {
      await showModalBottomSheet<void>(context: context, builder: (_) => const _IosInstructions());
      return;
    }
    final accepted = await promptInstall();
    if (!mounted) return;
    if (accepted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تمّ التثبيت! ستجد «كنوز» على شاشة هاتفك')));
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == InstallState.installed || _state == InstallState.unavailable) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: _onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black.withValues(alpha: .25),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: kFont, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.install_mobile_rounded),
      label: const Text('ثبّت التطبيق على هاتفك'),
    );
  }
}

class _IosInstructions extends StatelessWidget {
  const _IosInstructions();

  @override
  Widget build(BuildContext context) {
    Widget step(int n, IconData icon, String text) => ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.purpleText,
            foregroundColor: Colors.white,
            child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          title: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          trailing: Icon(icon, color: AppColors.blue, size: 28),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تثبيت «كنوز» على iPhone',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.purpleText)),
            const SizedBox(height: 12),
            step(1, Icons.ios_share_rounded, 'اضغط زرّ المشاركة أسفل Safari'),
            step(2, Icons.add_box_outlined, 'اختر «إضافة إلى الشاشة الرئيسية»'),
            step(3, Icons.check_circle_outline_rounded, 'اضغط «إضافة» في الأعلى'),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
          ],
        ),
      ),
    );
  }
}
