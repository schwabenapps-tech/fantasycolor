import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert, ob der fortgeschrittene Pixel-/Malen-nach-Zahlen-Modus
/// (nach Interstitial) freigeschaltet ist.
class PixelModeUnlockStore extends ChangeNotifier {
  PixelModeUnlockStore();

  static const _prefsKey = 'pixel_mode_unlocked';

  bool _unlocked = false;
  bool _ready = false;

  bool get isReady => _ready;
  bool get isUnlocked => _unlocked;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _unlocked = prefs.getBool(_prefsKey) ?? false;
    _ready = true;
    notifyListeners();
  }

  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }
}
