import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import "../Utils/Routes.dart";
import "login.dart";
import '../utils/api_config.dart';
import '../design/design.dart';

class doneTask extends StatefulWidget {
  const doneTask({super.key});

  @override
  State<doneTask> createState() => _doneTaskState();
}

class _doneTaskState extends State<doneTask> {

  Future<void> TaskDoneAPI() async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    const String apiUrl = '$kBaseUrl/team/taskDone';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization' :storedValue,
      },

      body: ({
        "teamCode": TeamCodeController.text,
        "domainName": DomainController.text,
        "email": EmailController.text,
        "task": TaskController.text,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tarea marcada como hecha"),),);

    } else {
      print(' ${response.statusCode}');
      print('Error Message: ${response.body}');
    }
  }

  TextEditingController EmailController =TextEditingController();
  TextEditingController DomainController =TextEditingController();
  TextEditingController TaskController =TextEditingController();
  TextEditingController TeamCodeController =TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
        Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.6, 0.8),
            end: Alignment(0.6, 0.21),
            colors: [Color(0xFF020918), Color(0xFF38486C)],
          ),
        ),
        child: DesktopCenter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              child: Column(
                children: [
                  const SizedBox(height: 80,),

                  const Text("Tarea completada",style:TextStyle(color: Colors.white,fontSize:40,fontWeight: FontWeight.w700),),
                  const SizedBox(height: 30,),


                  Container(
                    width: 303,
                    height: 400,
                    decoration: ShapeDecoration(
                      color: Colors.white.withOpacity(0.15000000596046448),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadiusDirectional.all(Radius.circular(30)),
                          child: Container(
                            height: 48,
                            width: 270,
                            color: Colors.white,
                            child: TextFormField(
                              controller: TeamCodeController,
                              decoration: InputDecoration(
                                prefixIcon:const Icon(Icons.groups_outlined),
                                hintText: "Código de equipo",
                                contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                                border:OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25,),
                        ClipRRect(
                          borderRadius: const BorderRadiusDirectional.all(Radius.circular(30)),
                          child: Container(
                            height: 48,
                            width: 265,
                            color: Colors.white,
                            child: TextFormField(
                              controller: DomainController,
                              decoration: InputDecoration(
                                prefixIcon:const Icon(Icons.domain),
                                hintText: "Área",
                                contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                                border:OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.0),
                                ),
                              ),
                            ),
                          ),
                        ),const SizedBox(height: 25,),
                        ClipRRect(
                          borderRadius: const BorderRadiusDirectional.all(Radius.circular(30)),
                          child: Container(
                            height: 48,
                            width: 265,
                            color: Colors.white,
                            child: TextFormField(
                              controller: EmailController,
                              decoration: InputDecoration(
                                prefixIcon:const Icon(Icons.email),
                                hintText: "Correo",
                                contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                                border:OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25,),
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
                        const SizedBox(height: 35,),
                        ElevatedButton(onPressed: (){
                          TaskDoneAPI();
                        },
                          style:ElevatedButton.styleFrom(
                            backgroundColor:const Color.fromARGB(255, 169, 187, 229),
                          ),
                          child:Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("Tarea completada"),
                              const SizedBox(width:5),
                              IconButton(onPressed:(){},icon:const Icon(Icons.arrow_circle_right_outlined)),
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

      ),
          const Align(alignment: Alignment.topLeft, child: FloatingBackButton()),
        ],
      ),
    );
  }
}
