import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Notas": bitácora simple de notas guardada en SharedPreferences.
///
/// IMPORTANTE (limitación conocida): estas notas viven SOLO en este
/// dispositivo (SharedPreferences), a diferencia de Imágenes y Documentos,
/// que sí se guardan en el backend y se comparten con todo el equipo. Si
/// más adelante quieres que las notas también sean compartidas, hace falta
/// agregar una tabla `notes` en la base de datos y endpoints en el backend
/// (mismo patrón que `documents`); avísame y lo armo.
///
/// Cada nota tiene un nombre opcional y un texto. La lista muestra cada
/// nota como un botón con su nombre (o una vista previa del texto si no se
/// puso nombre); al tocarlo se abre una pantalla completa con el título
/// arriba y el texto completo debajo.
class DocumentationPage extends StatefulWidget {
  @override
  _DocumentationPageState createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController updateController = TextEditingController();
  List<UpdateItem> updates = [];

  @override
  void initState() {
    super.initState();
    loadUpdates();
  }

  @override
  void dispose() {
    nameController.dispose();
    updateController.dispose();
    super.dispose();
  }

  void loadUpdates() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String existingUpdates = prefs.getString('updates') ?? '';
    setState(() {
      updates = UpdateItem.fromStoredString(existingUpdates);
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('updates', UpdateItem.toStoredString(updates));
  }

  /// Guarda una nota nueva. `name` es opcional: si se deja vacío, la nota
  /// se guarda igual (solo con texto) y en la lista se muestra una vista
  /// previa del texto en lugar de un nombre.
  void saveUpdate(String name, String text) async {
    if (text.trim().isEmpty) return;
    final newUpdate = UpdateItem(
      name: name.trim().isEmpty ? null : name.trim(),
      text: text.trim(),
      dateTime: DateTime.now(),
    );
    setState(() => updates.insert(0, newUpdate));
    await _persist();
    nameController.clear();
    updateController.clear();
    FocusScope.of(context).unfocus();
    if (mounted) Navigator.pop(context); // cierra el bottom sheet
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota guardada con éxito.')),
      );
    }
  }

  Future<bool> _deleteUpdate(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Eliminar nota',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '¿Seguro que quieres eliminar esta nota? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    setState(() => updates.removeAt(index));
    await _persist();
    return true;
  }

  void _showAddNoteSheet() {
    nameController.clear();
    updateController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Nueva nota',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'El nombre es opcional. Se guarda en este dispositivo.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: nameController,
                hintText: 'Nombre de la nota (opcional)',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: updateController,
                hintText: 'Escribe tu progreso o una nota...',
                maxLines: 6,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Guardar nota',
                height: 48,
                onPressed: () =>
                    saveUpdate(nameController.text, updateController.text),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openNote(int index) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(
          update: updates[index],
          onDelete: () => _deleteUpdate(index),
        ),
      ),
    );
    // NoteDetailScreen ya hizo el pop con `true` después de borrar
    // exitosamente, así que aquí solo hace falta refrescar la lista.
    if (deleted == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ResourceHeader(
                title: 'Notas',
                subtitle: 'Registra el progreso y las notas del equipo.',
              ),
              Expanded(
                child: updates.isEmpty
                    ? const EmptyState(
                        icon: Icons.sticky_note_2_outlined,
                        title: 'Todavía no hay notas',
                        message: 'Toca el botón + para agregar la primera.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                          bottom: 96, // espacio para el FAB
                        ),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemCount: updates.length,
                        itemBuilder: (context, index) {
                          return _NoteButton(
                            update: updates[index],
                            onTap: () => _openNote(index),
                          );
                        },
                      ),
              ),
            ],
          ),
          // FAB en esquina inferior derecha
          Positioned(
            bottom: AppSpacing.xl,
            right: AppSpacing.lg,
            child: _UploadFab(onPressed: _showAddNoteSheet),
          ),
        ],
      ),
    );
  }
}

/// Fila-botón de una nota en la lista: solo muestra el nombre (o una vista
/// previa del texto si no se puso nombre) y la fecha. Tocarla abre la nota
/// completa en [NoteDetailScreen].
class _NoteButton extends StatelessWidget {
  const _NoteButton({required this.update, required this.onTap});
  final UpdateItem update;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.sticky_note_2_rounded,
                color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  update.formattedDateTime,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Pantalla completa de una nota: título arriba, texto completo debajo, y
/// un botón de eliminar en la barra superior.
class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({
    super.key,
    required this.update,
    required this.onDelete,
  });

  final UpdateItem update;
  /// Debe devolver `true` si la nota se borró de verdad (el usuario
  /// confirmó el diálogo), `false` si canceló.
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Text(
                  update.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final deleted = await onDelete();
                  if (deleted && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                tooltip: 'Eliminar nota',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 56, right: AppSpacing.lg),
            child: Text(
              update.formattedDateTime,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                update.text,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// FAB reutilizable con gradiente de la marca
class _UploadFab extends StatelessWidget {
  const _UploadFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child:
            const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class UpdateItem {
  /// Nombre de la nota. Opcional: puede ser null si el usuario dejó el
  /// campo vacío al crearla.
  String? name;
  String text;
  DateTime dateTime;

  UpdateItem({this.name, required this.text, required this.dateTime});

  /// Lo que se muestra como "botón" en la lista: el nombre si existe, o si
  /// no una vista previa corta del texto (una nota sin nombre igual debe
  /// poder identificarse en la lista).
  String get displayTitle {
    final trimmedName = (name ?? '').trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final preview = text.trim().replaceAll('\n', ' ');
    if (preview.isEmpty) return 'Nota sin título';
    return preview.length > 42 ? '${preview.substring(0, 42)}…' : preview;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'text': text,
        'dateTime': dateTime.toIso8601String(),
      };

  factory UpdateItem.fromJson(Map<String, dynamic> json) => UpdateItem(
        name: json['name'] as String?,
        text: (json['text'] as String?) ?? '',
        dateTime: DateTime.tryParse((json['dateTime'] as String?) ?? '') ??
            DateTime.now(),
      );

  /// Formato de almacenamiento: JSON (una lista de notas). Antes se
  /// guardaba como líneas "texto~fecha" separadas por salto de línea, lo
  /// cual además se rompía si el texto de una nota tenía saltos de línea
  /// propios. JSON resuelve ambos problemas: es a prueba de saltos de
  /// línea y ahora también guarda el nombre.
  static String toStoredString(List<UpdateItem> updates) {
    return jsonEncode(updates.map((u) => u.toJson()).toList());
  }

  /// Lee JSON (formato actual). Si el contenido guardado es del formato
  /// viejo (de antes de este cambio), cae de vuelta a ese parseo para no
  /// perder las notas que la persona ya tenía guardadas en el dispositivo.
  static List<UpdateItem> fromStoredString(String storedString) {
    if (storedString.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(storedString);
      if (decoded is List) {
        return decoded
            .map((e) => UpdateItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // No es JSON: probablemente el formato viejo. Se intenta abajo.
    }
    return storedString
        .split('\n')
        .where((element) => element.isNotEmpty)
        .map((updateString) {
      final parts = updateString.split('~');
      return UpdateItem(
        text: parts[0],
        dateTime: parts.length > 1
            ? (DateTime.tryParse(parts[1]) ?? DateTime.now())
            : DateTime.now(),
      );
    }).toList();
  }

  String get formattedDateTime {
    return DateFormat('d MMM yyyy, HH:mm').format(dateTime);
  }
}