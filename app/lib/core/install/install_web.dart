import 'dart:js_interop';

import 'install.dart';

// Fonctions définies dans web/index.html.
@JS('konozInstallState')
external JSString _state();

@JS('konozPromptInstall')
external JSPromise<JSString> _prompt();

@JS('konozOnInstallChange')
external void _onChange(JSFunction callback);

InstallState currentInstallState() {
  try {
    return switch (_state().toDart) {
      'installed' => InstallState.installed,
      'available' => InstallState.available,
      'ios' => InstallState.ios,
      _ => InstallState.unavailable,
    };
  } catch (_) {
    return InstallState.unavailable; // page sans le script (ex. ancienne démo)
  }
}

/// Ouvre la fenêtre d'installation du navigateur. `true` si l'utilisateur accepte.
Future<bool> promptInstall() async {
  try {
    return (await _prompt().toDart).toDart == 'accepted';
  } catch (_) {
    return false;
  }
}

void onInstallChange(void Function() callback) {
  try {
    _onChange(callback.toJS);
  } catch (_) {}
}
