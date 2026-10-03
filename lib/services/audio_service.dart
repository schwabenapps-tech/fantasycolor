import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ruhige Hintergrundmusik + kurze Erfolgs-Sounds.
///
/// Wichtig für iOS/audioplayers: Play/Stop/Source-Wechsel strikt serialisieren.
///
/// Musik ist beim App-Start immer an. Mute gilt nur für die aktuelle Session
/// und wird nicht über Neustarts hinweg gespeichert.
class AudioService extends ChangeNotifier {
  AudioService._();

  static final AudioService instance = AudioService._();

  /// Legacy-Key — wird beim Start gelöscht, damit alte Mute-Prefs verschwinden.
  static const _prefsMutedKey = 'audio_muted';

  static const calmTracks = <String>[
    'sounds/ambient_01_nymphs.mp3',
    'sounds/ambient_02_moon.mp3',
    'sounds/ambient_03_voyage.mp3',
    'sounds/ambient_04_cinematic.mp3',
  ];

  static const levelCompleteSfx = 'sounds/sfx_complete.mp3';

  AudioPlayer? _music;
  AudioPlayer? _sfx;
  StreamSubscription<void>? _musicCompleteSub;

  bool _ready = false;
  bool _muted = false;
  bool _musicWanted = false;
  String? _currentAsset;
  Future<void>? _initFuture;

  /// Zufällige Reihenfolge: jedes Lied einmal, dann neu mischen.
  final List<String> _shuffleBag = <String>[];
  final _rng = Random();

  Future<void> _musicGate = Future<void>.value();
  Timer? _ambientDebounce;

  bool get muted => _muted;
  bool get isReady => _ready;
  int get calmTrackCount => calmTracks.length;

  Future<void> initialize() {
    if (_ready) return Future<void>.value();
    return _initFuture ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    // Immer mit Musik starten — alten Mute-Stand verwerfen.
    _muted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsMutedKey)) {
        await prefs.remove(_prefsMutedKey);
      }
    } catch (e, st) {
      debugPrint('AudioService prefs cleanup failed: $e\n$st');
    }

    final ctx = AudioContextConfig(
      route: AudioContextConfigRoute.system,
      focus: AudioContextConfigFocus.gain,
      respectSilence: false,
      stayAwake: false,
    ).build();
    await AudioPlayer.global.setAudioContext(ctx);

    await _createPlayers(ctx);
    _ready = true;
    notifyListeners();
  }

  Future<void> _createPlayers(AudioContext ctx) async {
    await _musicCompleteSub?.cancel();
    _musicCompleteSub = null;
    try {
      await _music?.dispose();
    } catch (_) {}
    try {
      await _sfx?.dispose();
    } catch (_) {}

    _music = AudioPlayer();
    _sfx = AudioPlayer();
    await _music!.setAudioContext(ctx);
    await _sfx!.setAudioContext(ctx);
    await _music!.setReleaseMode(ReleaseMode.stop);
    await _music!.setVolume(0.28);
    await _music!.setPlayerMode(PlayerMode.mediaPlayer);
    await _sfx!.setReleaseMode(ReleaseMode.stop);
    await _sfx!.setVolume(0.7);
    await _sfx!.setPlayerMode(PlayerMode.lowLatency);

    _musicCompleteSub = _music!.onPlayerComplete.listen((_) {
      _enqueueMusic(() async {
        _currentAsset = null;
        await _playNextTrackUnlocked();
      });
    });
  }

  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    // Nur Session — kein Persistieren über App-Neustart.
    _muted = value;
    notifyListeners();
    await _enqueueMusic(() async {
      final player = _music;
      if (player == null) return;
      if (_muted) {
        try {
          await player.pause();
        } catch (_) {}
      } else if (_musicWanted) {
        await _ensurePlayingUnlocked(force: true);
      }
    });
  }

  Future<void> toggleMuted() => setMuted(!_muted);

  /// Startet die Fantasy-Loop-Musik (debounced).
  Future<void> startAmbient() async {
    await initialize();
    _ambientDebounce?.cancel();
    _ambientDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_enqueueMusic(_startAmbientUnlocked));
    });
  }

  Future<void> _startAmbientUnlocked() async {
    final firstStart = !_musicWanted;
    _musicWanted = true;

    if (!firstStart) {
      if (_muted) return;
      await _ensurePlayingUnlocked(force: false);
      return;
    }

    _refillShuffleBag(avoid: null);
    _currentAsset = null;
    if (_muted) return;
    await _ensurePlayingUnlocked(force: true);
  }

  Future<void> stopAmbient() async {
    _ambientDebounce?.cancel();
    await _enqueueMusic(() async {
      _musicWanted = false;
      _currentAsset = null;
      try {
        await _music?.stop();
      } catch (_) {}
    });
  }

  /// App im Hintergrund / Display aus → Musik pausieren.
  Future<void> pauseForBackground() async {
    _ambientDebounce?.cancel();
    await _enqueueMusic(() async {
      try {
        await _music?.pause();
      } catch (_) {}
    });
  }

  /// App wieder aktiv → Ambient fortsetzen (wenn gewünscht und nicht stumm).
  Future<void> resumeFromBackground() async {
    if (!_musicWanted || _muted) return;
    await initialize();
    await _enqueueMusic(() => _ensurePlayingUnlocked(force: false));
  }

  Future<void> playLevelComplete() async {
    await initialize();
    if (_muted) return;
    final sfx = _sfx;
    if (sfx == null) return;
    try {
      await sfx.stop();
      await sfx.play(AssetSource(levelCompleteSfx));
    } catch (e, st) {
      debugPrint('AudioService.playLevelComplete failed: $e\n$st');
    }
  }

  Future<void> _enqueueMusic(Future<void> Function() op) {
    final run = _musicGate.then((_) => op());
    _musicGate = run.catchError((Object e, StackTrace st) {
      debugPrint('AudioService queue error: $e\n$st');
    });
    return run;
  }

  Future<void> _ensurePlayingUnlocked({required bool force}) async {
    if (_muted || !_musicWanted) return;
    final player = _music;
    if (player == null) return;

    if (!force) {
      final state = player.state;
      if (state == PlayerState.playing) return;
      if (state == PlayerState.paused && _currentAsset != null) {
        try {
          await player.resume();
          return;
        } catch (e, st) {
          debugPrint('AudioService resume failed: $e\n$st');
        }
      }
    }
    await _playNextTrackUnlocked();
  }

  /// Mischt alle Tracks neu. Vermeidet denselben Track wie zuletzt zuerst.
  void _refillShuffleBag({required String? avoid}) {
    _shuffleBag
      ..clear()
      ..addAll(calmTracks);
    _shuffleBag.shuffle(_rng);
    if (_shuffleBag.length > 1 &&
        avoid != null &&
        _shuffleBag.first == avoid) {
      final swap = 1 + _rng.nextInt(_shuffleBag.length - 1);
      final tmp = _shuffleBag[0];
      _shuffleBag[0] = _shuffleBag[swap];
      _shuffleBag[swap] = tmp;
    }
  }

  /// Nächstes Lied aus dem Zufallsbeutel; Beutel neu mischen wenn leer.
  String? _takeNextShuffledTrack() {
    if (calmTracks.isEmpty) return null;
    if (_shuffleBag.isEmpty) {
      _refillShuffleBag(avoid: _currentAsset);
    }
    if (_shuffleBag.isEmpty) return null;
    // Zusätzlich: zufälligen Slot aus dem Rest wählen (stärkerer Zufall).
    final idx = _rng.nextInt(_shuffleBag.length);
    return _shuffleBag.removeAt(idx);
  }

  Future<void> _playNextTrackUnlocked() async {
    if (_muted || !_musicWanted) return;
    if (calmTracks.isEmpty) return;

    for (var attempt = 0; attempt < calmTracks.length; attempt++) {
      final asset = _takeNextShuffledTrack();
      if (asset == null) return;
      // Nie dasselbe Lied direkt nochmal, falls nur 1 übrig war und Beutel neu.
      if (asset == _currentAsset && calmTracks.length > 1) {
        continue;
      }
      final ok = await _playAssetUnlocked(asset);
      if (ok) return;
    }

    debugPrint('AudioService: all tracks failed — recreating player');
    await _recreateMusicPlayer();
    if (_muted || !_musicWanted) return;
    final asset = _takeNextShuffledTrack();
    if (asset != null) {
      await _playAssetUnlocked(asset);
    }
  }

  Future<bool> _playAssetUnlocked(String asset) async {
    final player = _music;
    if (player == null) return false;
    try {
      debugPrint('AudioService: playing $asset');
      await player.play(AssetSource(asset));
      _currentAsset = asset;
      return true;
    } catch (e, st) {
      debugPrint('AudioService music failed ($asset): $e\n$st');
      _currentAsset = null;
      return false;
    }
  }

  Future<void> _recreateMusicPlayer() async {
    final ctx = AudioContextConfig(
      route: AudioContextConfigRoute.system,
      focus: AudioContextConfigFocus.gain,
      respectSilence: false,
      stayAwake: false,
    ).build();
    await _musicCompleteSub?.cancel();
    _musicCompleteSub = null;
    try {
      await _music?.dispose();
    } catch (_) {}
    _music = AudioPlayer();
    await _music!.setAudioContext(ctx);
    await _music!.setReleaseMode(ReleaseMode.stop);
    await _music!.setVolume(0.28);
    await _music!.setPlayerMode(PlayerMode.mediaPlayer);
    _musicCompleteSub = _music!.onPlayerComplete.listen((_) {
      _enqueueMusic(() async {
        _currentAsset = null;
        await _playNextTrackUnlocked();
      });
    });
  }

  @override
  void dispose() {
    _ambientDebounce?.cancel();
    unawaited(_musicCompleteSub?.cancel());
    unawaited(_music?.dispose());
    unawaited(_sfx?.dispose());
    super.dispose();
  }
}
