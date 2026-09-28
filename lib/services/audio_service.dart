import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ruhige Hintergrundmusik + kurze Erfolgs-Sounds.
///
/// Wichtig für iOS/audioplayers: Play/Stop/Source-Wechsel strikt serialisieren.
class AudioService extends ChangeNotifier {
  AudioService._();

  static final AudioService instance = AudioService._();

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
  int _trackIndex = 0;
  String? _currentAsset;
  Future<void>? _initFuture;

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
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_prefsMutedKey) ?? false;

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
    _muted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsMutedKey, value);
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

    if (calmTracks.isNotEmpty) {
      _trackIndex = Random().nextInt(calmTracks.length);
    }
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

  Future<void> _playNextTrackUnlocked() async {
    if (_muted || !_musicWanted) return;
    if (calmTracks.isEmpty) return;

    for (var attempt = 0; attempt < calmTracks.length; attempt++) {
      _trackIndex = _trackIndex % calmTracks.length;
      final asset = calmTracks[_trackIndex];
      _trackIndex = (_trackIndex + 1) % calmTracks.length;

      final ok = await _playAssetUnlocked(asset);
      if (ok) return;
    }

    debugPrint('AudioService: all tracks failed — recreating player');
    await _recreateMusicPlayer();
    if (_muted || !_musicWanted) return;
    final asset = calmTracks[_trackIndex % calmTracks.length];
    _trackIndex = (_trackIndex + 1) % calmTracks.length;
    await _playAssetUnlocked(asset);
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
