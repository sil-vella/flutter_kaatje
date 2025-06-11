import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../tools/logging/logger.dart';

class AudioModule extends ModuleBase {
  static final Logger _log = Logger(); // ✅ Use a static logger
  static bool _isMuted = false; // ✅ Global mute state
  final Map<String, AudioPlayer> _audioPlayers = {}; // ✅ Active players
  final Map<String, AudioPlayer> _preloadedPlayers = {}; // ✅ Preloaded players
  final Set<String> _currentlyPlaying = {}; // ✅ Tracks active sounds
  final Random _random = Random();

  /// ✅ Constructor
  AudioModule() : super("audio_module") {
    _log.info('✅ AudioModule initialized.');
  }

  @override
  void initialize(BuildContext context) {
    _log.info('✅ AudioModule initialized with context.');
  }

  /// ✅ Getter for global mute state
  static bool get isMuted => _isMuted;

  /// ✅ Get currently playing sounds
  Set<String> get currentlyPlaying => _currentlyPlaying;

  /// ✅ Get preloaded players
  Map<String, AudioPlayer> get preloadedPlayers => _preloadedPlayers;


  final Map<String, String> correctSounds = {
    "correct_1": "assets/audio/correct01.mp3",
  };

  final Map<String, String> incorrectSounds = {
    "incorrect_1": "assets/audio/incorrect01.mp3",
  };

  final Map<String, String> levelUpSounds = {
    "level_up_1": "assets/audio/level_up001.mp3",
  };

  final Map<String, String> flushingFiles = {
    "flushing_1": "assets/audio/flush007.mp3",
  };

  /// ✅ Preload all sounds
  Future<void> preloadAll() async {
    final soundMaps = [
      correctSounds,
      incorrectSounds,
      levelUpSounds,
      flushingFiles,
    ];

    for (var soundMap in soundMaps) {
      for (var filePath in soundMap.values) {
        if (!_preloadedPlayers.containsKey(filePath)) {
          final preloadedPlayer = AudioPlayer();
          try {
            await preloadedPlayer.setAsset(filePath);
            _preloadedPlayers[filePath] = preloadedPlayer;
            _log.info('🎵 Preloaded: $filePath');
          } catch (e) {
            _log.error('❌ Error preloading audio: $filePath | Error: $e');
          }
        }
      }
    }
  }

  /// ✅ Play sound from a list (Random)
  Future<void> playFromList(Map<String, String> soundMap, {double volume = 1.0}) async {
    if (soundMap.isEmpty) return;

    final keys = soundMap.keys.toList();
    final randomKey = keys[_random.nextInt(keys.length)];
    await playSpecific(randomKey, soundMap, volume: volume);
  }

  /// ✅ Play a specific sound
  Future<void> playSpecific(String key, Map<String, String> soundMap, {double volume = 1.0}) async {
    final filePath = soundMap[key];
    if (filePath == null) return;

    await stopAll(); // ✅ Ensure only one sound plays at a time

    final player = _audioPlayers.putIfAbsent(filePath, () => AudioPlayer());
    await player.setVolume(_isMuted ? 0.0 : volume);
    await player.setAsset(filePath);
    await player.play();
    _currentlyPlaying.add(filePath);
  }

  /// ✅ Play looping sound from a list
  Future<void> loopFromList(BuildContext context, Map<String, String> soundList, {double volume = 1.0}) async {
    if (soundList.isEmpty) return;

    final keys = soundList.keys.toList();
    final randomKey = keys[_random.nextInt(keys.length)];
    final filePath = soundList[randomKey];

    if (filePath == null) return;

    // ✅ Stop currently playing sounds from this list
    for (final path in soundList.values) {
      if (_currentlyPlaying.contains(path)) {
        await stopSound(soundList, soundList.keys.firstWhere((k) => soundList[k] == path));
      }
    }

    final player = _preloadedPlayers[filePath] ?? _audioPlayers.putIfAbsent(filePath, () => AudioPlayer());
    await player.setVolume(_isMuted ? 0.0 : volume);
    await player.setLoopMode(LoopMode.one);
    await player.setAsset(filePath);
    await player.play();
    _currentlyPlaying.add(filePath);
  }

  /// ✅ Stop a specific sound
  Future<void> stopSound(Map<String, String> soundList, String key) async {
    final filePath = soundList[key];
    if (filePath == null) return;

    if (_audioPlayers.containsKey(filePath)) {
      final player = _audioPlayers[filePath]!;
      await player.stop();
      await player.dispose();
      _audioPlayers.remove(filePath);
      _currentlyPlaying.remove(filePath);
      _log.info('⏹️ Stopped: $filePath');
    } else {
      _log.error('⚠️ Audio player for "$filePath" not found.');
    }
  }

  /// ✅ Stop all sounds
  Future<void> stopAll() async {
    for (var player in _audioPlayers.values) {
      if (player.playing) {
        await player.stop();
      }
      await player.dispose();
    }
    _audioPlayers.clear();
    _currentlyPlaying.clear();
    _log.info('🔇 Stopped all audio.');
  }

  /// ✅ Dispose method to clean up resources
  @override
  void dispose() {
    _log.info('🗑 AudioModule disposed.');
    stopAll();
    super.dispose();
  }

  /// ✅ Toggle mute state and save preference
  static Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    _applyMuteState();
    _saveMuteState();
  }

  /// ✅ Mute all sounds
  static Future<void> muteAll() async {
    _isMuted = true;
    _applyMuteState();
  }

  /// ✅ Unmute all sounds
  static Future<void> unmuteAll() async {
    _isMuted = false;
    _applyMuteState();
  }

  /// ✅ Stop all instances
  static Future<void> stopAllInstances() async {
    final moduleManager = ModuleManager();
    final audioModule = moduleManager.getLatestModule<AudioModule>();
    audioModule?.stopAll();
  }

  /// ✅ Apply mute state
  static void _applyMuteState() {
    final moduleManager = ModuleManager();
    final audioModule = moduleManager.getLatestModule<AudioModule>();

    if (audioModule != null) {
      for (var player in audioModule._audioPlayers.values) {
        player.setVolume(_isMuted ? 0.0 : 1.0);
      }
    }
  }

  /// ✅ Save mute state in SharedPreferences
  static Future<void> _saveMuteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isMuted', _isMuted);
      _log.info('🔇 Mute state saved: $_isMuted');
    } catch (e) {
      _log.error("❌ Error saving mute state: $e");
    }
  }
}
