import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Utils/Routes.dart';
import 'login.dart';
import '../utils/api_config.dart';
import '../design/design.dart';
class Mresign extends StatefulWidget {
   Mresign({super.key, required this.teamId,required this.emailId});
   String? teamId;
   String? emailId;

  @override
  State<Mresign> createState() => _MresignState();
}

class _MresignState extends State<Mresign> {
  Future<void> MresignApi(String? teamId, String? email) async {
    dynamic storedValue = await secureStorage.readSecureData(key);
    final String apiUrl = '$kBaseUrl/user/sendMessage/$teamId';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Authorization' :storedValue,
      },

      body: ({
        "Correo": email,
        "message":MessageController.text,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Correo enviado"),),);
      Navigator.pushReplacementNamed(context, MyRoutes.BottomNavBar);
    } else {
      print( ' ${response.statusCode}');
      print('Error Message: ${response.body}');
    }
  }
  TextEditingController MessageController=TextEditingController();
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
                  const SizedBox(height: 100,),

                  const Text("Renunciar",style:TextStyle(color: Colors.white,fontSize:40,fontWeight: FontWeight.w700),),
                  const SizedBox(height: 30,),


                  Container(
                    width: 303,
                    height: 300,
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
                          child: Container(
                            height: 200,
                            width: 270,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                maxLines: 10,
                                controller: MessageController,
                                decoration: InputDecoration(
                                  hintText: "Mensaje para el líder",
                                  contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                                  border:OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25,),
                        ElevatedButton(onPressed: (){
                          MresignApi(widget.teamId, widget.emailId);
                        },
                          style:ElevatedButton.styleFrom(
                            backgroundColor:const Color.fromARGB(255, 169, 187, 229),
                          ),
                          child:const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Enviar renuncia"),
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
