import 'install.dart';

InstallState currentInstallState() => InstallState.installed;

Future<bool> promptInstall() async => false;

void onInstallChange(void Function() callback) {}
