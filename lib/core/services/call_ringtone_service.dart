import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class CallRingtoneService {
  static AudioPlayer? _player;
  static bool _isPlaying = false;

  // Royalty-free, reliable direct audio URLs for telephone tones
  static const String _ringbackToneUrl =
      'https://cdn.freesound.org/previews/274/274178_5121236-lq.mp3';
  static const String _incomingRingtoneUrl =
      'https://cdn.freesound.org/previews/536/536422_4921277-lq.mp3';

  /// Plays repeating ringback tone (for caller when receiver is ringing)
  static Future<void> playRingback() async {
    try {
      await stop();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(0.85);
      await _player!.play(UrlSource(_ringbackToneUrl));
      _isPlaying = true;
    } catch (e) {
      debugPrint('[CallRingtoneService] Ringback audio error: $e');
    }
  }

  /// Plays repeating melodic ringtone (for receiver on incoming call)
  static Future<void> playIncomingRing() async {
    try {
      await stop();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      await _player!.play(UrlSource(_incomingRingtoneUrl));
      _isPlaying = true;
    } catch (e) {
      debugPrint('[CallRingtoneService] Incoming ring audio error: $e');
    }
  }

  /// Stops all ringing sounds immediately
  static Future<void> stop() async {
    if (!_isPlaying && _player == null) return;
    try {
      _isPlaying = false;
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}

