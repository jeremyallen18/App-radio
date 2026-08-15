import 'dart:convert';
import 'package:doliv_social/ResourceM/doc.dart';
import 'package:doliv_social/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../design/design.dart';

class LeaderResource extends StatefulWidget {
  final String teamId;

  LeaderResource(this.teamId);

  @override
  _LeaderResourceState createState() => _LeaderResourceState();
}

class _LeaderResourceState extends State<LeaderResource> {
  TextEditingController emailController = TextEditingController();
  TextEditingController messageController = TextEditingController();

  Future<void> sendMessage() async {
    String storedValue = await secureStorage.readSecureData(key);

    var headers = {
      'Authorization': storedValue,
      'Content-Type': 'application/json',
    };

    var request = http.Request(
      'POST',
      Uri.parse(
          '$kBaseUrl/user/sendMessage/${widget.teamId}'),
    );
    request.body = json.encode({
      "Correo": emailController.text,
      "message": messageController.text,
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      print(await response.stream.bytesToString());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Mensaje enviado con éxito!'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print(response.reasonPhrase);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el mensaje. Inténtalo de nuevo.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.black,
        backgroundColor: Color.fromARGB(255, 10, 20, 43),
        title: const Text('Asistencia del líder'),
        foregroundColor: Colors.white,
        elevation: 12,
        surfaceTintColor: Colors.black,
        leading: AppBackButton.leadingFor(context),
        automaticallyImplyLeading: false,
      ),
      body: DesktopCenter(
      maxWidth: 480,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MyTextField12(
                hintText: 'Correo para enviar mensaje',
                inputType: TextInputType.name,
                labelText2: 'Correo</> ',
                secure1: false,
                capital: TextCapitalization.none,
                nameController1: emailController),
            const SizedBox(height: 16),
            MyTextField2(
                hintText: 'Escribe tu mensaje',
                inputType: TextInputType.name,
                labelText2: 'Mensaje</>',
                secure1: false,
                capital: TextCapitalization.none,
                nameController1: messageController),
            const SizedBox(height: 16),

            Buttonkii(buttonName: 'Send Message', 
            onTap:  sendMessage,
            bgColor: Colors.black, textColor: Colors.white),
            
          ],
        ),
      ),
      ),
    );
  }
}

class MyTextField2 extends StatelessWidget {
  const MyTextField2({
    super.key,
    required this.hintText,
    required this.inputType,
    required this.labelText2,
    required this.secure1,
    required this.capital,
    required this.nameController1,
  });

  final String hintText;
  final TextInputType inputType;
  final String labelText2;
  final bool secure1;
  final TextCapitalization capital;
  final TextEditingController nameController1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
         maxLines: 5,
        style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
        controller: nameController1,
        keyboardType: inputType,
        obscureText: secure1,
        textInputAction: TextInputAction.next,
        textCapitalization: capital,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(20),
          hintText: hintText,
          hintStyle: const TextStyle(color: Color.fromARGB(255, 10, 18, 38)),
          enabledBorder: const OutlineInputBorder(
            borderSide:
                BorderSide(color: Color.fromARGB(255, 10, 18, 38), width: 1),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide:
                BorderSide(color: Color.fromARGB(255, 10, 18, 38), width: 1),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          labelText: labelText2,
          labelStyle: const TextStyle(color: Color.fromARGB(255, 10, 18, 38)),
        ),
      ),
    );
  }
}
class MyTextField12 extends StatelessWidget {
  const MyTextField12({
    super.key,
    required this.hintText,
    required this.inputType,
    required this.labelText2,
    required this.secure1,
    required this.capital,
    required this.nameController1,
  });

  final String hintText;
  final TextInputType inputType;
  final String labelText2;
  final bool secure1;
  final TextCapitalization capital;
  final TextEditingController nameController1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
       // maxLines: 5,
        style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
        controller: nameController1,
        keyboardType: inputType,
        obscureText: secure1,
        textInputAction: TextInputAction.next,
        textCapitalization: capital,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(20),
          hintText: hintText,
          hintStyle: const TextStyle(color: Color.fromARGB(255, 10, 18, 38)),
          enabledBorder: const OutlineInputBorder(
            borderSide:
                BorderSide(color: Color.fromARGB(255, 10, 18, 38), width: 1),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide:
                BorderSide(color: Color.fromARGB(255, 10, 18, 38), width: 1),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          labelText: labelText2,
          labelStyle: const TextStyle(color: Color.fromARGB(255, 10, 18, 38)),
        ),
      ),
    );
  }
}

