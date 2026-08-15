import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import 'app_button.dart';
import 'desktop_center.dart';

/// Pantalla completa de "sin señal", hermana de `web/404.html` pero para la
/// app nativa: mismo chiste de radio ("se cortó la transmisión"), mismos
/// colores de marca. La muestra [ConnectivityGate] cuando no hay conexión
/// con el backend.
class OfflineView extends StatefulWidget {
  const OfflineView({super.key, this.onRetry, this.retrying = false});

  final VoidCallback? onRetry;
  final bool retrying;

  @override
  State<OfflineView> createState() => _OfflineViewState();
}

class _OfflineViewState extends State<OfflineView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgBase,
      child: SafeArea(
        child: DesktopCenter(
          maxWidth: 420,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dial(controller: _controller),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    '88.4 FM · SIN SEÑAL',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.accentStrong, AppColors.accent],
                    ).createShader(bounds),
                    child: const Text(
                      'Sin conexión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '¡Se nos cortó la transmisión!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Radiodoliv no encuentra tu internet por ningún dial. '
                    'Revisa el wifi o los datos móviles e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _StaticBars(controller: _controller),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Text(
                      '"Estimados oyentes, la conexión salió a comprar '
                      'cigarros y no ha vuelto." — El de sonido, probablemente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Reintentar sintonía',
                    loading: widget.retrying,
                    onPressed: widget.onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
          ),
          RotationTransition(
            turns: controller,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentStrong,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),
          const Icon(Icons.wifi_off_rounded, color: AppColors.textPrimary, size: 34),
        ],
      ),
    );
  }
}

class _StaticBars extends StatelessWidget {
  const _StaticBars({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final double t = (controller.value * 2 * math.pi) + (i * 0.9);
              final double height = 6 + (22 * (0.5 + 0.5 * math.sin(t)));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
