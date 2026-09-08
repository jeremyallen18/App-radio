import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:doliv_social/design/design.dart';

/// Seis casillas para el código de recuperación.
///
/// Debajo hay UN solo `TextField` invisible que ocupa toda la fila: así el
/// foco, el auto-avance, el borrado y el pegado del código completo los
/// resuelve el propio campo (no hay que mover el foco entre seis campos), y el
/// autocompletado de SMS/correo (`AutofillHints.oneTimeCode`) funciona.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;

  /// Se llama cuando el código llega a [length] dígitos.
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final active = _focus.hasFocus;
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                Expanded(
                  child: _Box(
                    digit: i < code.length ? code[i] : null,
                    // La casilla "actual" es la siguiente a escribir (o la
                    // última cuando ya está completo).
                    current: active && (i == code.length || (code.length == widget.length && i == widget.length - 1)),
                  ),
                ),
                if (i < widget.length - 1) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          // Campo real: transparente, encima de las casillas para que tocar
          // cualquiera de ellas le dé el foco.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                enableInteractiveSelection: false,
                showCursor: false,
                maxLength: widget.length,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.current});

  final String? digit;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field - 4),
        border: Border.all(
          color: current
              ? AppColors.accentStrong
              : filled
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : AppColors.surfaceBorder,
          width: current ? 2 : 1,
        ),
        boxShadow: current
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        digit ?? (current ? '_' : ''),
        style: TextStyle(
          color: filled ? AppColors.textPrimary : AppColors.textMuted,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
