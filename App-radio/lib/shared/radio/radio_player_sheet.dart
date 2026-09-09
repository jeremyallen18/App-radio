import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/core/audio/radio_player.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/radio/radio_schedule_screen.dart';

/// Abre el panel del reproductor de Radio Doliv (play/stop, volumen, lo que
/// suena ahora y acceso a la programación del día).
Future<void> showRadioPlayer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgBase,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _RadioPlayerSheet(),
  );
}

class _RadioPlayerSheet extends StatefulWidget {
  const _RadioPlayerSheet();

  @override
  State<_RadioPlayerSheet> createState() => _RadioPlayerSheetState();
}

class _RadioPlayerSheetState extends State<_RadioPlayerSheet> {
  final _radio = RadioPlayer.instance;
  late RadioPlaybackState _state = _radio.state;
  late String? _nowPlaying = _radio.nowPlaying;
  late double _volume = _radio.volume;
  double? _volumeBeforeMute;

  StreamSubscription<RadioPlaybackState>? _stateSub;
  StreamSubscription<String?>? _nowSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _radio.onStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _nowSub = _radio.onNowPlayingChanged.listen((t) {
      if (mounted) setState(() => _nowPlaying = t);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _nowSub?.cancel();
    super.dispose();
  }

  bool get _isPlaying => _state == RadioPlaybackState.playing;
  bool get _isLoading => _state == RadioPlaybackState.loading;
  bool get _isMuted => _volume == 0;

  Future<void> _toggle() async {
    try {
      await _radio.toggle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo conectar con la transmisión en vivo.')),
      );
    }
  }

  Future<void> _setVolume(double v) async {
    setState(() => _volume = v);
    await _radio.setVolume(v);
  }

  Future<void> _toggleMute() async {
    if (_isMuted) {
      await _setVolume(_volumeBeforeMute ?? 1.0);
    } else {
      _volumeBeforeMute = _volume;
      await _setVolume(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Radio Doliv',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                const SizedBox(width: AppSpacing.sm),
                _LiveTag(playing: _isPlaying),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _nowPlaying ??
                  (_isPlaying ? 'Transmisión en vivo' : 'Fuera del aire'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Play / Stop grande.
            Center(
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _toggle,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isPlaying
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded),
                label: Text(_isPlaying ? 'DETENER' : 'ESCUCHAR EN VIVO'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Volumen.
            Row(
              children: [
                IconButton(
                  onPressed: _toggleMute,
                  icon: Icon(_isMuted
                      ? Icons.volume_off_rounded
                      : _volume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded),
                  color: AppColors.textPrimary,
                  tooltip: _isMuted ? 'Quitar silencio' : 'Silenciar',
                ),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: _setVolume,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${(_volume * 100).round()}%',
                      textAlign: TextAlign.end,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RadioScheduleScreen(),
                ));
              },
              icon: const Icon(Icons.calendar_view_day_outlined, size: 18),
              label: const Text('Ver programación del día'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTag extends StatelessWidget {
  const _LiveTag({required this.playing});
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final color = playing ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(playing ? 'EN VIVO' : 'PAUSADA',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
