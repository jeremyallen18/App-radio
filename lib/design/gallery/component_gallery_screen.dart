import 'package:flutter/material.dart';
import '../design.dart';

/// Pantalla de referencia visual del sistema de diseño (Fase 0). No forma
/// parte del flujo de usuario: es para revisar tokens y componentes de un
/// vistazo. Accesible desde [MyRoutes.ComponentGallery] en modo debug.
class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Galería de componentes')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Paleta'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _swatch('bgBase', AppColors.bgBase),
              _swatch('surface', AppColors.surface),
              _swatch('surfaceBorder', AppColors.surfaceBorder),
              _swatch('brandNavy', AppColors.brandNavy),
              _swatch('brandBlue', AppColors.brandBlue),
              _swatch('accent', AppColors.accent),
              _swatch('accentStrong', AppColors.accentStrong),
              _swatch('success', AppColors.success),
              _swatch('warning', AppColors.warning),
              _swatch('error', AppColors.error),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeader(title: 'Tipografía'),
          Text('Título grande (displaySmall)', style: Theme.of(context).textTheme.displaySmall),
          Text('Título medio (headlineMedium)', style: Theme.of(context).textTheme.headlineMedium),
          Text('Título de sección (titleLarge)', style: Theme.of(context).textTheme.titleLarge),
          Text('Cuerpo principal (bodyLarge)', style: Theme.of(context).textTheme.bodyLarge),
          Text('Cuerpo secundario (bodyMedium)', style: Theme.of(context).textTheme.bodyMedium),
          Text('Etiqueta (labelSmall)', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeader(title: 'Botones'),
          AppButton(label: 'Botón primario', onPressed: () {}),
          const SizedBox(height: AppSpacing.md),
          const AppButton(label: 'Cargando…', loading: true, onPressed: null),
          const SizedBox(height: AppSpacing.md),
          const AppButton(label: 'Deshabilitado', onPressed: null),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton(onPressed: () {}, child: const Text('Secundario')),
              const SizedBox(width: AppSpacing.md),
              TextButton(onPressed: () {}, child: const Text('Texto')),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeader(title: 'Campo de texto'),
          const AppTextField(hintText: 'Correo electrónico'),
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeader(title: 'Tarjeta y métrica'),
          Row(
            children: [
              const Expanded(
                child: StatTile(icon: Icons.task_alt, value: '12', label: 'Tareas activas'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  icon: Icons.groups,
                  value: '4',
                  label: 'Departamentos',
                  accentColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeader(title: 'Insignias'),
          const Wrap(
            spacing: AppSpacing.sm,
            children: [
              AppBadge(label: 'Pendiente'),
              AppBadge(label: 'Aprobado', variant: AppBadgeVariant.success),
              AppBadge(label: 'Advertencia', variant: AppBadgeVariant.warning),
              AppBadge(label: 'Rechazado', variant: AppBadgeVariant.error),
              AppBadge(label: 'Info', variant: AppBadgeVariant.info),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeader(title: 'Estados'),
          const SizedBox(height: 140, child: LoadingState(message: 'Cargando…')),
          const SizedBox(
            height: 180,
            child: EmptyState(
              title: 'Nada por aquí todavía',
              message: 'Cuando tengas datos, aparecerán aquí.',
            ),
          ),
          SizedBox(
            height: 240,
            child: ErrorState(onRetry: () {}),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _swatch(String name, Color color) {
    return Container(
      width: 96,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
