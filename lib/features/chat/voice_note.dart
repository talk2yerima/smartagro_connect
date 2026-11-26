import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/constants/app_colors.dart';
import '../../core/i18n/i18n.dart';
import '../../core/utils/app_logger.dart';

/// Longest voice note; recording stops and sends itself at this point.
const maxVoiceNote = Duration(minutes: 2);

/// Records chat voice notes small enough for mobile data: mono AAC at
/// 32 kbps / 16 kHz, about 4 KB per second (a 1-minute note is ~240 KB).
class VoiceNoteRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;

  /// Asks for the microphone if needed. Returns false when refused.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
    return true;
  }

  /// Stops and returns the file and its length, or null if nothing usable
  /// was recorded (under half a second counts as an accidental tap).
  Future<({String path, Duration duration})?> stop() async {
    final path = await _recorder.stop();
    final started = _startedAt;
    _startedAt = null;
    if (path == null || started == null) return null;
    final duration = DateTime.now().difference(started);
    if (duration < const Duration(milliseconds: 500)) {
      _deleteQuietly(path);
      return null;
    }
    return (path: path, duration: duration);
  }

  Future<void> cancel() async {
    _startedAt = null;
    await _recorder.cancel();
  }

  Future<void> dispose() => _recorder.dispose();

  static void _deleteQuietly(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }
}

/// Uploads a recorded note to Firebase Storage and returns its URL.
Future<String> uploadVoiceNote({
  required String threadId,
  required String messageId,
  required String filePath,
}) async {
  final ref =
      FirebaseStorage.instance.ref('chat_audio/$threadId/$messageId.m4a');
  await ref.putFile(
    File(filePath),
    SettableMetadata(
      contentType: 'audio/mp4',
      cacheControl: 'public, max-age=604800',
    ),
  );
  VoiceNoteRecorder._deleteQuietly(filePath);
  return ref.getDownloadURL();
}

String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Replaces the message box while recording: a pulsing red dot, the
/// running time, and big Cancel / Send buttons (no press-and-hold needed).
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    super.key,
    required this.elapsed,
    required this.onCancel,
    required this.onSend,
    required this.isDark,
  });

  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final left = maxVoiceNote - elapsed;
    return Row(
      children: [
        IconButton(
          tooltip: tr('Cancel voice note'),
          onPressed: onCancel,
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.errorRed,
        ),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 10),
                Text(
                  formatClock(elapsed),
                  style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(isDark),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    left.inSeconds <= 15
                        ? '${left.inSeconds}s left'
                        : 'Recording…',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.subText(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: tr('Send voice note'),
          child: Material(
            color: AppColors.deepGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.errorRed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// A voice note inside a chat bubble: play/pause, a seekable progress bar
/// and the time. The audio is only downloaded when someone taps play.
class VoiceNoteBubble extends StatefulWidget {
  const VoiceNoteBubble({
    super.key,
    required this.source,
    required this.duration,
    required this.color,
    this.uploading = false,
  });

  /// A download URL, or a local file path while the note is still sending.
  final String? source;
  final Duration? duration;
  final Color color;
  final bool uploading;

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _total = widget.duration;
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<AudioPlayer?> _ensurePlayer() async {
    if (_player != null) return _player;
    final src = widget.source;
    if (src == null || src.isEmpty) return null;
    final player = AudioPlayer();
    _player = player;
    setState(() => _loading = true);
    try {
      final d = src.startsWith('http')
          ? await player.setUrl(src)
          : await player.setFilePath(src);
      if (d != null) _total = d;
    } catch (e) {
      log.w('[Voice] load failed: $e');
      await player.dispose();
      _player = null;
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: T("Couldn't play this voice note. Check your "
                'connection and try again.')));
      }
      return null;
    }
    _stateSub = player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        player.pause();
        player.seek(Duration.zero);
      }
      if (mounted) {
        setState(() => _playing =
            s.playing && s.processingState != ProcessingState.completed);
      }
    });
    _posSub = player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    if (mounted) setState(() => _loading = false);
    return player;
  }

  Future<void> _toggle() async {
    final player = await _ensurePlayer();
    if (player == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      unawaited(player.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final busy = _loading || widget.uploading;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: widget.color),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: _playing ? 'Pause voice note' : 'Play voice note',
                    onPressed: _toggle,
                    icon: Icon(
                      _playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 36,
                      color: widget.color,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: widget.color,
                    inactiveTrackColor: widget.color.withValues(alpha: 0.3),
                    thumbColor: widget.color,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: _player == null
                        ? null
                        : (v) => _player!.seek(Duration(
                            milliseconds: (v * total.inMilliseconds).round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    widget.uploading
                        ? 'Sending…'
                        : formatClock(_playing || _position > Duration.zero
                            ? _position
                            : total),
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: widget.color.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
