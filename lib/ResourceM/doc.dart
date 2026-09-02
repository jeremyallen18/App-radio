import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design/design.dart';
import 'resource_header.dart';

/// Pantalla "Documentación": bitácora simple de avances/notas guardada en
/// el dispositivo (SharedPreferences). Migrada al sistema de diseño: el
/// formulario y el historial ahora usan `AppTextField`/`AppButton`/
/// `AppCard` en vez de los campos y botones dibujados a mano que tenía
/// antes (bordes, sombras y colores fijos repetidos en cada pantalla de
/// Resource Manager).
class DocumentationPage extends StatefulWidget {
  @override
  _DocumentationPageState createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  final TextEditingController updateController = TextEditingController();
  List<UpdateItem> updates = [];

  @override
  void initState() {
    super.initState();
    loadUpdates();
  }

  void loadUpdates() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String existingUpdates = prefs.getString('updates') ?? '';
    setState(() {
      updates = UpdateItem.fromStoredString(existingUpdates);
    });
  }

  void saveUpdate(String update) async {
    if (update.trim().isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    UpdateItem newUpdate = UpdateItem(text: update.trim(), dateTime: DateTime.now());
    setState(() {
      updates.insert(0, newUpdate);
    });
    prefs.setString('updates', UpdateItem.toStoredString(updates));
    updateController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ResourceHeader(
            title: 'Documentación',
            subtitle: 'Registra el progreso y las notas del equipo.',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: updateController,
                  hintText: 'Escribe tu progreso o una nota...',
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 180,
                    child: AppButton(
                      label: 'Guardar nota',
                      height: 44,
                      onPressed: () => saveUpdate(updateController.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Historial (${updates.length})'),
          Expanded(
            child: updates.isEmpty
                ? const EmptyState(
                    icon: Icons.menu_book_rounded,
                    title: 'Todavía no hay notas',
                    message: 'Lo que escribas arriba aparecerá aquí.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemCount: updates.length,
                    itemBuilder: (context, index) {
                      final update = updates[index];
                      return AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.description_rounded, color: AppColors.accent, size: 20),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    update.text,
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    update.formattedDateTime,
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class UpdateItem {
  String text;
  DateTime dateTime;

  UpdateItem({required this.text, required this.dateTime});

  static String toStoredString(List<UpdateItem> updates) {
    return updates
        .map((update) => '${update.text}~${update.dateTime.toIso8601String()}')
        .join('\n');
  }

  static List<UpdateItem> fromStoredString(String storedString) {
    List<String> updateStrings = storedString.split('\n');
    return updateStrings
        .where((element) => element.isNotEmpty)
        .map((updateString) {
      List<String> parts = updateString.split('~');
      return UpdateItem(text: parts[0], dateTime: DateTime.parse(parts[1]));
    }).toList();
  }

  String get formattedDateTime {
    return DateFormat('d MMM yyyy, HH:mm').format(dateTime);
  }
}
