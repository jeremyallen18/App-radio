import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doliv_social/design/design.dart';

class DocumentationPage extends StatefulWidget {
  const DocumentationPage({super.key});

  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  TextEditingController updateController = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Documentación'),
        automaticallyImplyLeading: false,
      ),
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Estas notas se guardan solo en este dispositivo, no se comparten con el equipo.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: updateController,
                  prefixIcon: Icon(Icons.edit_note_outlined,
                      color: AppColors.textMuted),
                  hintText: 'Escribe tu progreso',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Guardar nota',
                  height: 46,
                  onPressed: () => saveUpdate(updateController.text),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Tus notas'),
              ],
            ),
          ),
          Expanded(
            child: updates.isEmpty
                ? const EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Todavía no tienes notas',
                    message:
                        'Escribe tu progreso arriba y guárdalo para verlo aquí.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    reverse: true,
                    itemCount: updates.length,
                    itemBuilder: (context, index) {
                      final update = updates[index];
                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              update.text,
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              update.formattedDateTime,
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
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

  void saveUpdate(String update) async {
    if (update.trim().isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    UpdateItem newUpdate = UpdateItem(text: update, dateTime: DateTime.now());
    setState(() {
      updates.insert(0, newUpdate);
    });
    prefs.setString('updates', UpdateItem.toStoredString(updates));
    updateController.clear();
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
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }
}
