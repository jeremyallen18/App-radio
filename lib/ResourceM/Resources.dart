import 'package:brl_task4/ResourceM/documents.dart';
import 'package:brl_task4/ResourceM/imagecc.dart';
import 'package:brl_task4/ResourceM/doc.dart';
import 'package:flutter/material.dart';
import '../design/design.dart';

/// Pantalla "Resource Manager": menú con tres accesos directos —
/// Archivos, Imágenes y Notas — cada uno con un diseño de tarjeta
/// visual atractivo con ícono grande, descripción y FAB de color.
class ResourceM extends StatelessWidget {
  final String teamId;
  ResourceM(this.teamId, {super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  'Resource Manager',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 56, right: AppSpacing.lg, top: 4),
            child: Text(
              'Gestiona los recursos de este equipo.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  _ResourceCard(
                    title: 'Archivos',
                    description: 'Sube y descarga documentos del equipo: PDF, Word, Excel y más.',
                    icon: Icons.folder_open_rounded,
                    accentColor: AppColors.accent,
                    gradientColors: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DocumentsScreen(teamId)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ResourceCard(
                    title: 'Imágenes',
                    description: 'Explora y sube imágenes compartidas por el equipo.',
                    icon: Icons.image_rounded,
                    accentColor: AppColors.success,
                    gradientColors: [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ImageListScreen(teamId)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ResourceCard(
                    title: 'Notas',
                    description: 'Registra y consulta notas informativas del equipo.',
                    icon: Icons.sticky_note_2_rounded,
                    accentColor: AppColors.warning,
                    gradientColors: [const Color(0xFF4A148C), const Color(0xFF6A1B9A)],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DocumentationPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatefulWidget {
  const _ResourceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

/// Tarjeta-botón del menú de Resource Manager. Antes era un simple
/// `GestureDetector` sin ningún tipo de retroalimentación táctil (ni
/// splash, ni cambio visual al presionar). Ahora:
/// - Usa `Material` + `InkWell` para el efecto de "ripple" nativo al tocar.
/// - Se encoge levemente mientras se mantiene presionada (`AnimatedScale`),
///   para que se sienta como un botón real y no solo una imagen tocable.
/// - El ícono va en un contenedor circular con un halo suave detrás en vez
///   de un cuadrado plano, y la flecha se desplaza un poco al presionar
///   para reforzar la sensación de "vas a entrar aquí".
class _ResourceCardState extends State<_ResourceCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.gradientColors,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card + 6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: widget.gradientColors[0].withValues(alpha: _pressed ? 0.22 : 0.38),
              blurRadius: _pressed ? 10 : 20,
              offset: Offset(0, _pressed ? 3 : 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card + 6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: SizedBox(
              height: 136,
              child: Stack(
                children: [
                  // Círculos decorativos de fondo
                  Positioned(
                    right: -24,
                    top: -28,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    bottom: -36,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  // Contenido principal
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        // Ícono circular con halo suave detrás, en vez del
                        // cuadrado plano anterior — se ve más "premium" y
                        // hace juego con la flecha (también circular).
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.15),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Icon(widget.icon, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        // Texto
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                widget.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // Flecha: se desliza levemente hacia la derecha al
                        // presionar, como una pequeña señal de "entrando".
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          transform: Matrix4.translationValues(_pressed ? 4 : 0, 0, 0),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
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