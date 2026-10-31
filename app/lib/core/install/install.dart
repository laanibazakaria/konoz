/// Installation de l'app depuis le navigateur (PWA).
/// Sur Android / iOS natifs, il n'y a rien à installer : la version « stub » répond toujours `installed`.
library;

export 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';

/// Ce que l'écran d'accueil peut proposer.
enum InstallState {
  /// Déjà installée, ou app native : on n'affiche rien.
  installed,

  /// Le navigateur propose l'installation (Chrome / Edge, Android et ordinateur).
  available,

  /// iPhone / iPad : pas de bouton système, on explique « Partager → Sur l'écran d'accueil ».
  ios,

  /// Navigateur sans installation possible (ex. Firefox ordinateur).
  unavailable,
}
