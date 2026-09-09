import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';
import 'package:doliv_social/design/components/app_button.dart';

/// Pantalla completa de "sin señal": el chiste de radio ("se cortó la
/// transmisión") con los colores de marca. La muestra [ConnectivityGate]
/// cuando no hay conexión
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
    return Material(
      color: AppColors.bgBase,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Dial(controller: _controller),
                        const SizedBox(height: AppSpacing.xl),
                        const _SignalChip(),
                        const SizedBox(height: AppSpacing.md),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
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
                        Text(
                          '¡Se nos cortó la transmisión!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Radiodoliv no encuentra tu internet por ningún dial. '
                          'Revisa el wifi o los datos móviles e inténtalo de nuevo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _StaticBars(controller: _controller),
                        const SizedBox(height: AppSpacing.xl),
                        const _QuoteCard(),
                        const SizedBox(height: AppSpacing.xl),
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
            );
          },
        ),
      ),
    );
  }
}

/// Etiqueta de estado sobre el título: punto ámbar + "SIN SEÑAL" dentro de una
/// píldora, para que se lea como un indicador y no como texto suelto.
class _SignalChip extends StatelessWidget {
  const _SignalChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          SizedBox(width: AppSpacing.sm),
          Text(
            'SIN SEÑAL',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.warning,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Cita deadpan del "chiste de radio". Comilla de acento como firma visual y
/// atribución separada en su propia línea.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '“',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Estimados oyentes, la conexión salió a comprar cigarros y no '
            'ha vuelto.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '— El de sonido, probablemente',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
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
          Icon(Icons.wifi_off_rounded, color: AppColors.textPrimary, size: 34),
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
