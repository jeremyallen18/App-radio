import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Utils/Routes.dart';
import 'login.dart';
import '../utils/api_config.dart';
import '../design/design.dart';

class Resign extends StatefulWidget {
  Resign({super.key, required this.teamId});
  String? teamId;
  @override
  State<Resign> createState() => _ResignState();
}

class _ResignState extends State<Resign> {
  TextEditingController MEmailController =TextEditingController();
  TextEditingController EmailController =TextEditingController();
  Future<void> removeApi(String? teamId) async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    print(teamId);
    print (storedValue);
    final String apiUrl = '$kBaseUrl/team/deleteMember/$teamId';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization' :storedValue,
      },

      body: ({
        "memberEmail": MEmailController.text,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Eliminado"),),);
      Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
    } else {
      print( ' ${response.statusCode}');
      print('Error Message: ${response.body}');
    }
  }

  Future<void> resignApi(String? teamId) async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    print(teamId);
    final String apiUrl = '$kBaseUrl/team/leaderResign/$teamId';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization' :storedValue,
      },

      body: ({
        "Correo": EmailController.text,
        }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Asignado"),),);
      Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
    } else {
      print( ' ${response.statusCode}');
      print('Error Message: ${response.body}');
    }
  }

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
            end: Alignment(0.4, 0.31),
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
                  const SizedBox(height: 70,),
                  Container(
                    width: 303,
                    height: 200,
                    decoration: ShapeDecoration(
                      color: Colors.white.withOpacity(0.15000000596046448),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Eliminar miembro",style:TextStyle(color: Colors.white,fontSize:30,fontWeight: FontWeight.w700),),
                        const SizedBox(height: 10,),
                        ClipRRect(
                          borderRadius: const BorderRadiusDirectional.all(Radius.circular(30)),
                          child: Container(
                            height: 48,
                            width: 270,
                            color: Colors.white,
                            child: TextFormField(
                              controller: MEmailController,
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
                        ElevatedButton(onPressed: (){
                          removeApi(widget.teamId);
                        },
                          style:ElevatedButton.styleFrom(
                            backgroundColor:const Color.fromARGB(255, 169, 187, 229),
                          ),
                          child:const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Eliminar"),
                              SizedBox(width:5),
                            ],
                          ),),

                      ],
                    ),
                  ),
                  const SizedBox(height: 40,),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 2, width: 138,color: Colors.white,),
                        const Text(" O ",style:TextStyle(color: Colors.white,fontSize:20,fontWeight: FontWeight.w700),),
                      Container(height: 2,width:138,color: Colors.white,),
                    ],
                  ),

                  const SizedBox(height: 40,),


                  Container(
                    width: 303,
                    height: 200,
                    decoration: ShapeDecoration(
                      color: Colors.white.withOpacity(0.15000000596046448),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Asignar nuevo líder",style:TextStyle(color: Colors.white,fontSize:30,fontWeight: FontWeight.w700),),
                        const SizedBox(height: 10,),
                        ClipRRect(
                          borderRadius: const BorderRadiusDirectional.all(Radius.circular(30)),
                          child: Container(
                            height: 48,
                            width: 270,
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
                        ElevatedButton(onPressed: (){
                          resignApi(widget.teamId);
                        },
                          style:ElevatedButton.styleFrom(
                            backgroundColor:const Color.fromARGB(255, 169, 187, 229),
                          ),
                          child:const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Asignar"),
                              SizedBox(width:5),
                            ],
                          ),),

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

