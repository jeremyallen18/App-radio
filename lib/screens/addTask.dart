import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Utils/Routes.dart';
import 'login.dart';
import '../utils/api_config.dart';

class addTask extends StatefulWidget {
  addTask({super.key, required this.teamcode, this.domains});
  dynamic teamcode;
  final List<dynamic>? domains;

  @override
  State<addTask> createState() => _addTaskState();
}

class _addTaskState extends State<addTask> {
  String? selectedDomain;
  String? selectedMember;

  List<String> get _domainNames =>
      (widget.domains ?? []).map((d) => d['name'].toString()).toSet().toList();

  List<String> get _membersForSelectedDomain {
    if (selectedDomain == null) return [];
    final domain = (widget.domains ?? []).firstWhere(
      (d) => d['name'] == selectedDomain,
      orElse: () => null,
    );
    if (domain == null) return [];
    return ((domain['members'] as List?) ?? []).map((m) => m.toString()).toSet().toList();
  }

  Future<void> addTaskAPI(String teamcode) async {
    if (selectedDomain == null || selectedDomain!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un área")),
      );
      return;
    }
    if (selectedMember == null || selectedMember!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona un miembro")),
      );
      return;
    }
    if (TaskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Describe la tarea")),
      );
      return;
    }
    if (DeadlineController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Indica la fecha límite")),
      );
      return;
    }

    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl = '$kBaseUrl/team/task/$teamcode';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization' :storedValue,
      },
      body: ({
        "domainName": selectedDomain,
        "email": selectedMember,
        "task": TaskController.text,
        "deadline": DeadlineController.text,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tarea agregada"),),);
        Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
    } else {
      print( ' ${response.statusCode}');
      print('Error Message: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo agregar la tarea")),
      );
    }
  }

  TextEditingController TaskController =TextEditingController();
  TextEditingController DeadlineController =TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.6, 0.8),
            end: Alignment(0.6, 0.21),
            colors: [Color(0xFF020918), Color(0xFF38486C)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              child: Column(
                children: [
                  const SizedBox(height: 80,),

                  const Text("Agregar tarea",style:TextStyle(color: Colors.white,fontSize:40,fontWeight: FontWeight.w700),),
                  const SizedBox(height: 30,),


                  Container(
                    width: 303,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: ShapeDecoration(
                      color: Colors.white.withOpacity(0.15000000596046448),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonFormField<String>(
                            value: selectedDomain,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.domain),
                              hintText: "Área",
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0)),
                            ),
                            items: _domainNames
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedDomain = value;
                                selectedMember = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20,),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonFormField<String>(
                            value: selectedMember,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.person),
                              hintText: selectedDomain == null
                                  ? "Elige un área primero"
                                  : "Miembro",
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0)),
                            ),
                            items: _membersForSelectedDomain
                                .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: selectedDomain == null
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedMember = value;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(height: 20,),
                        ClipRRect(
                          borderRadius: const BorderRadiusDirectional.all(Radius.circular(30)),
                          child: Container(
                            height: 48,
                            width: 265,
                            color: Colors.white,
                            child: TextFormField(
                              controller: TaskController,
                              decoration: InputDecoration(
                                prefixIcon:const Icon(Icons.add_box_rounded),
                                hintText: "Tarea",
                                contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                                border:OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20,),
                        ClipRRect(
                          borderRadius: const BorderRadiusDirectional.all(Radius.circular(30)),
                          child: Container(
                            height: 48,
                            width: 265,
                            color: Colors.white,
                            child: TextFormField(
                              controller: DeadlineController,
                              decoration: InputDecoration(
                                prefixIcon:const Icon(Icons.calendar_month),
                                hintText: "30-11-2023",
                                contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                                border:OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30,),
                        ElevatedButton(onPressed: (){
                          addTaskAPI(widget.teamcode);
                        },
                          style:ElevatedButton.styleFrom(
                            backgroundColor:const Color.fromARGB(255, 169, 187, 229),
                          ),
                          child:Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("Agregar tarea"),
                              const SizedBox(width:5),
                              const Icon(Icons.arrow_circle_right_outlined),
                            ],
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
