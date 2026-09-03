import 'dart:convert';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

class ApplyLeave extends StatefulWidget {
  final String teamid;

  ApplyLeave({required this.teamid});

  @override
  _ApplyLeaveState createState() => _ApplyLeaveState();
}

class _ApplyLeaveState extends State<ApplyLeave> {
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  Future<String?> applyLeaveAPI(
      String startDate, String endDate, String reason) async {

    String StoreLeaveId;
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl =
        '$kBaseUrl/leave/applyLeave/${widget.teamid}';

    var body = jsonEncode({"leaves": [
      {
        "startDate": startDate,
        "endDate": endDate,
        "reason": reason,
      }]
    });

    var headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': storedValue,
    };

    try {
      var response =
          await http.post(Uri.parse(apiUrl), headers: headers, body: body);

      if (response.statusCode == 200) {
        print('Leave applied successfully');
        StoreLeaveId = jsonDecode(response.body)['_id'];
        print(jsonDecode(response.body));
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Permiso solicitado con éxito!'),
          ),
        );
        LeaveID(StoreLeaveId);
        return null;
      } else {
        print('Error: ${response.statusCode}');
        print(jsonDecode(response.body));
        String error = jsonDecode(response.body)['error'];
        if (!mounted) return error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
          ),
        );
        return jsonDecode(response.body)['error'];

      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de red al solicitar el permiso')),
        );
      }
      return e.toString();
    }
  }

  Future<void> LeaveID(String StoreLeaveID) async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl =
        '$kBaseUrl/leave/leaveResult/$StoreLeaveID';

    var headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': storedValue,
      'leaveId' : StoreLeaveID,
    };
    http.post(Uri.parse(apiUrl), headers: headers);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final today = dateOnly(now);
    final picked = await pickWorkingDate(
      context,
      initialDate: today,
      firstDate: today, // no se piden permisos para fechas ya pasadas
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    setState(() => controller.text = '$dd-$mm-${picked.year}');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Solicitar permiso'),
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      scrollable: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Indica la fecha de inicio, la fecha de fin y el motivo de tu permiso.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: startDateController,
              prefixIcon: const Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
              hintText: 'Fecha de inicio',
              readOnly: true,
              onTap: () => _pickDate(startDateController),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Indica la fecha de inicio';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: endDateController,
              prefixIcon: const Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
              hintText: 'Fecha de fin',
              readOnly: true,
              onTap: () => _pickDate(endDateController),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Indica la fecha de fin';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: reasonController,
              prefixIcon: const Icon(Icons.description_outlined, color: AppColors.textMuted),
              hintText: 'Motivo del permiso',
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Indica el motivo del permiso';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _submitting ? 'Enviando…' : 'Solicitar permiso',
              loading: _submitting,
              onPressed: _submitting ? null : () => _applyLeave(context),
            ),
          ],
        ),
      ),
    );
  }

  void _applyLeave(BuildContext context) async {
    if (_formKey.currentState?.validate() ?? false) {
      String startDate = startDateController.text;
      String endDate = endDateController.text;
      String reason = reasonController.text;

      setState(() => _submitting = true);
      try {
        await applyLeaveAPI(startDate, endDate, reason);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }
}
