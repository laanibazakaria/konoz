import 'package:flutter/services.dart';

/// قائمة الصور الموجودة فعلاً في التطبيق، تُقرأ مرة واحدة عند التشغيل.
///
/// لماذا؟ Flutter لا يحتفظ في الذاكرة بالصور التي فشل تحميلها، فإذا كانت صورة
/// غير موجودة وأُعيد بناء العنصر (مثلاً أثناء رسم متحرك) يُعاد طلبها في كل إطار.
/// لذلك لا نطلب إلا الصور المضمّنة، ونعرض الرسم البديل مباشرة لغيرها.
abstract final class AppAssets {
  static Set<String> _available = const {};

  static Future<void> load([AssetBundle? bundle]) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      _available = manifest.listAssets().toSet();
    } catch (_) {
      _available = const {};
    }
  }

  static bool has(String path) => _available.contains(path);

  /// للاختبارات فقط.
  static set debugAvailable(Set<String> paths) => _available = paths;
}

/// مسارات الصور المستخدمة في الواجهة.
abstract final class AssetPaths {
  static const mascot = 'assets/characters/mascot.png';
  static const parchment = 'assets/ui/parchment.png';
  static const woodCard = 'assets/ui/wood_card.png';
  static const home = 'assets/backgrounds/home.png';
}
