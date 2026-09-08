import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Cada pantalla de autenticación es una "frecuencia" del dial. El orden es el
/// del flujo real: entrar, crear cuenta y, si se olvidó la contraseña, los tres
/// pasos de recuperación.
enum AuthStation {
  login,
  signUp,
  resetEmail,
  resetCode,
  resetPassword;

  /// Posición horizontal (0..1) de la aguja en [FrequencyDial].
  double get position => 0.15 + index * 0.175;

  /// Paso 1..3 dentro de la recuperación; `null` fuera de ella.
  int? get recoveryStep {
    switch (this) {
      case AuthStation.resetEmail:
        return 1;
      case AuthStation.resetCode:
        return 2;
      case AuthStation.resetPassword:
        return 3;
      case AuthStation.login:
      case AuthStation.signUp:
        return null;
    }
  }
}

/// Cabecera común de login / registro / recuperación: logo del unicornio
/// sobre un aro con halo, el dial de sintonía con la aguja en la estación
/// actual, y el bloque eyebrow + título + subtítulo.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.station,
    required this.title,
    this.subtitle,
    this.eyebrow,
  });

  final AuthStation station;
  final String title;
  final String? subtitle;

  /// Texto pequeño en mayúsculas sobre el título. Si es `null` se deriva de la
  /// estación ("Radio Doliv · Acceso", "Recuperar acceso · Paso 2 de 3"...).
  final String? eyebrow;

  String get _eyebrow {
    if (eyebrow != null) return eyebrow!;
    final step = station.recoveryStep;
    if (step != null) return 'Recuperar acceso · Paso $step de 3';
    return station == AuthStation.signUp
        ? 'Radio Doliv · Nueva cuenta'
        : 'Radio Doliv · Acceso';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _LogoDisc()),
        const SizedBox(height: AppSpacing.xl),
        FrequencyDial(position: station.position),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _eyebrow.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.accentStrong,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _LogoDisc extends StatelessWidget {
  const _LogoDisc();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image.asset('assets/logo/logo.png', fit: BoxFit.contain),
    );
  }
}

/// Regla de sintonizador: marcas finas, cinco marcas de "estación" (una por
/// pantalla) y la aguja en [position]. Al montarse, la aguja se desliza desde
/// el centro hasta su estación; con animaciones desactivadas aparece ya en
/// su sitio.
class FrequencyDial extends StatelessWidget {
  const FrequencyDial({super.key, required this.position});

  /// 0..1 a lo ancho del dial.
  final double position;

  static const double height = 30;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? position : 0.5, end: position),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _DialPainter(needle: value, stations: AuthStation.values.length),
          size: const Size(double.infinity, height),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.needle, required this.stations});

  final double needle;
  final int stations;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final baseY = size.height - 4;
    const tickGap = 6.0;
    final tick = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Marcas finas; se desvanecen hacia los bordes como un dial real.
    for (double x = 0; x <= w; x += tickGap) {
      final t = x / w;
      final edgeFade = (1 - (2 * t - 1).abs()).clamp(0.25, 1.0);
      final i = (x / tickGap).round();
      final major = i % 5 == 0;
      tick.color = AppColors.textMuted.withValues(alpha: (major ? 0.6 : 0.3) * edgeFade);
      canvas.drawLine(Offset(x, baseY), Offset(x, baseY - (major ? 12 : 6)), tick);
    }

    // Marcas de estación (una por pantalla de auth).
    for (var s = 0; s < stations; s++) {
      final x = AuthStation.values[s].position * w;
      tick.color = AppColors.accent.withValues(alpha: 0.55);
      tick.strokeWidth = 1.5;
      canvas.drawLine(Offset(x, baseY), Offset(x, baseY - 16), tick);
    }

    // Línea base.
    canvas.drawLine(
      Offset(0, baseY),
      Offset(w, baseY),
      Paint()
        ..color = AppColors.surfaceBorder
        ..strokeWidth = 1,
    );

    // Aguja con halo.
    final nx = needle * w;
    canvas.drawLine(
      Offset(nx, baseY + 3),
      Offset(nx, 2),
      Paint()
        ..color = AppColors.accentStrong.withValues(alpha: 0.35)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(nx, baseY + 3),
      Offset(nx, 2),
      Paint()
        ..color = AppColors.accentStrong
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final head = Path()
      ..moveTo(nx - 4, 0)
      ..lineTo(nx + 4, 0)
      ..lineTo(nx, 5)
      ..close();
    canvas.drawPath(head, Paint()..color = AppColors.accentStrong);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.needle != needle || old.stations != stations;
}
