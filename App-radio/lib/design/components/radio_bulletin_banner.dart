import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:doliv_social/models/broadcast_notice.dart';

/// Place around the Navigator in MaterialApp.builder. Only the banner itself
/// receives pointer events; there is no barrier over the active screen.
class RadioBulletinHost extends StatefulWidget {
  const RadioBulletinHost({
    super.key,
    required this.child,
    required this.notice,
    required this.onDismiss,
    this.onOpen,
  });

  final Widget child;
  final ValueListenable<BroadcastNotice?> notice;
  final ValueChanged<BroadcastNotice> onDismiss;
  final ValueChanged<BroadcastNotice>? onOpen;

  @override
  State<RadioBulletinHost> createState() => _RadioBulletinHostState();
}

class _RadioBulletinHostState extends State<RadioBulletinHost>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    setState(() => _foreground = foreground);
    final notice = widget.notice.value;
    if (!foreground && notice != null) widget.onDismiss(notice);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay.wrap(
      child: Stack(
        children: [
          widget.child,
          if (_foreground)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: MediaQuery.paddingOf(context).left + 12,
              right: MediaQuery.paddingOf(context).right + 12,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ValueListenableBuilder<BroadcastNotice?>(
                    valueListenable: widget.notice,
                    builder: (context, notice, _) => notice == null
                        ? const SizedBox.shrink()
                        : RadioBulletinBanner(
                            key: ObjectKey(notice),
                            title: notice.title,
                            preview: notice.preview,
                            onDismissed: () => widget.onDismiss(notice),
                            onTap: widget.onOpen == null
                                ? null
                                : () => widget.onOpen!(notice),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable notice surface. The parent removes it after [onDismissed].
/// A new key starts a new notice; title and preview may otherwise update live.
class RadioBulletinBanner extends StatefulWidget {
  const RadioBulletinBanner({
    super.key,
    required this.title,
    required this.preview,
    required this.onDismissed,
    this.onTap,
    this.holdDuration = const Duration(seconds: 6),
  }) : assert(holdDuration > Duration.zero);

  final String title;
  final String preview;
  final VoidCallback onDismissed;
  final VoidCallback? onTap;
  final Duration holdDuration;

  @override
  State<RadioBulletinBanner> createState() => _RadioBulletinBannerState();
}

class _RadioBulletinBannerState extends State<RadioBulletinBanner>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade = _entrance.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  late final Animation<Offset> _slide = _fade.drive(
    Tween(begin: const Offset(0, -1.15), end: Offset.zero),
  );
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _dismissibleKey = UniqueKey();
  Timer? _timer;
  bool _started = false;
  bool _reduceMotion = false;
  bool _leaving = false;
  bool _notified = false;
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _ambient.stop();
      _entrance.value = _leaving ? 0 : 1;
      if (_leaving) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      }
    } else if (!_leaving && !_ambient.isAnimating) {
      _ambient.repeat(reverse: true);
    }
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _armTimer();
    } else {
      _entrance.forward().whenCompleteOrCancel(() {
        if (mounted && !_leaving) _armTimer();
      });
    }
  }

  void _armTimer() {
    _timer?.cancel();
    if (_leaving || _hovered || _focused || _dragging) return;
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final duration = accessible && widget.holdDuration.inSeconds < 12
        ? const Duration(seconds: 12)
        : widget.holdDuration;
    _timer = Timer(duration, _dismiss);
  }

  void _finish() {
    if (!mounted || _notified) return;
    _notified = true;
    _timer?.cancel();
    _ambient.stop();
    widget.onDismissed();
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    _ambient.stop();
    if (_reduceMotion) {
      _finish();
      return;
    }
    try {
      await _entrance.reverse().orCancel;
      _finish();
    } on TickerCanceled {
      // Replacement, route teardown, or logout removed the banner.
    }
  }

  void _open() {
    if (_leaving) return;
    _leaving = true;
    _finish();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Dismissible(
          key: _dismissibleKey,
          direction: DismissDirection.horizontal,
          resizeDuration: null,
          movementDuration:
              _reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          onUpdate: (details) {
            _dragging = details.progress > 0;
            _armTimer();
          },
          onDismissed: (_) {
            _leaving = true;
            _finish();
          },
          child: MouseRegion(
            onEnter: (_) {
              _hovered = true;
              _armTimer();
            },
            onExit: (_) {
              _hovered = false;
              _armTimer();
            },
            child: Focus(
              onFocusChange: (focused) {
                _focused = focused;
                _armTimer();
              },
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (context, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: colors.secondary.withValues(
                          alpha: 0.08 +
                              (_reduceMotion ? 0 : _ambient.value * 0.06),
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Material(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: colors.secondary.withValues(alpha: 0.45)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: widget.onTap == null ? null : _open,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ExcludeSemantics(
                                    child: Row(
                                      children: [
                                        Icon(Icons.sensors,
                                            size: 16, color: colors.secondary),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text('ON AIR',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0,
                                                color: colors.secondary,
                                              )),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 42,
                                          height: 16,
                                          child: RepaintBoundary(
                                            child: CustomPaint(
                                                painter: _BulletinWave(
                                              animation: _ambient,
                                              color: colors.secondary,
                                              reduceMotion: _reduceMotion,
                                            )),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onSurface,
                                        letterSpacing: 0),
                                  ),
                                  if (widget.preview.trim().isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: colors.onSurfaceVariant,
                                          letterSpacing: 0),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar aviso',
                          onPressed: _dismiss,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletinWave extends CustomPainter {
  _BulletinWave(
      {required this.animation,
      required this.color,
      required this.reduceMotion})
      : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var x = 0.0; x <= size.width; x++) {
      final envelope = math.sin(x / size.width * math.pi);
      final phase = reduceMotion ? 0 : animation.value * math.pi * 2;
      final y = size.height / 2 + math.sin(x * 0.45 - phase) * envelope * 5;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_BulletinWave oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.animation != animation ||
      oldDelegate.reduceMotion != reduceMotion;
}
