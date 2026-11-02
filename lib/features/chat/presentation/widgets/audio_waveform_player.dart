import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioWaveformPlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const AudioWaveformPlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<AudioWaveformPlayer> createState() => _AudioWaveformPlayerState();
}

class _AudioWaveformPlayerState extends State<AudioWaveformPlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 15); // default fallback
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  // Varied bar heights to create a realistic voice waveform
  static const List<double> _barHeights = [
    6, 12, 18, 10, 22, 14, 8, 20, 24, 16,
    10, 18, 14, 8, 22, 26, 12, 18, 10, 16,
    20, 14, 8, 12, 6, 14, 10
  ];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() {
          _duration = dur;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMe ? Colors.white : const Color(0xFF6366F1);
    final inactiveColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.grey.shade300;

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final activeBarCount = (_barHeights.length * progress).round();

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // Play / Pause Circle
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white
                    : const Color(0xFF6366F1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? const Color(0xFF6366F1) : Colors.white,
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Waveform bars
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_barHeights.length, (i) {
                final isPassed = i <= activeBarCount;
                return Container(
                  width: 2.5,
                  height: _barHeights[i],
                  decoration: BoxDecoration(
                    color: isPassed ? activeColor : inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_isPlaying ? _position : _duration),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

