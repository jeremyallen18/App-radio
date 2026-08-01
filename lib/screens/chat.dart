import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:brl_task4/screens/chatHistory.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class ChatScreen extends StatefulWidget {
  final String name;

  const ChatScreen(this.name, {super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  late String myUsername;
  final Map<String, Color> userColors = {};
  Timer? _pollTimer;

  static const String _chatApiUrl =
      '$kBaseUrl/chat/getAllChats';
  static const String _sendApiUrl =
      '$kBaseUrl/chat/sendMessage';

  @override
  void initState() {
    super.initState();
    myUsername = widget.name;
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await http.get(Uri.parse(_chatApiUrl));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> chats = decoded['chats'] ?? [];
        setState(() {
          _messages
            ..clear()
            ..addAll(chats.map((c) => {
                  'message': c['message'],
                  'username': c['username'],
                }));
          for (final m in _messages) {
            final username = m['username'];
            if (username != null && !userColors.containsKey(username)) {
              userColors[username] = _generateRandomColor();
            }
          }
        });
      }
    } catch (e) {
      print('Failed to fetch chat messages: $e');
    }
  }

  Color _generateRandomColor() {
    return Color((Random().nextDouble() * 0xFFFFFF).toInt())
        .withOpacity(1.0);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    _controller.clear();
    try {
      final response = await http.post(Uri.parse(_sendApiUrl), body: {
        'username': myUsername,
        'message': text,
      });
      if (response.statusCode == 200) {
        await _fetchMessages();
      } else {
        print('Failed to send message: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Failed to send message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 12,
        shadowColor: Colors.black,
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 8, 18, 43),
        actions: [
          IconButton(
              icon: const Icon(
                Icons.history,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) =>  ChatScreenfetch()));
              }),
        ],

        title: Text(
          'Chat </>',

          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(
            height: 5.0,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index]['message'];
                final username = _messages[index]['username'];

                return Align(
                  alignment: username == myUsername
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    margin:
                        const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    decoration: BoxDecoration(
                      color: userColors[username] ??
                          const Color.fromARGB(255, 92, 92, 214),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '$username:\n $message',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                    child: MyTextField3(
                        hintText: 'Escribe tu mensaje',
                        inputType: TextInputType.name,
                        labelText2: 'Mensaje</>',
                        secure1: false,
                        capital: TextCapitalization.none,
                        nameController1: _controller)),
                IconButton(
                  icon: const Icon(Icons.send_sharp),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

class MyTextField3 extends StatelessWidget {
  const MyTextField3({
    super.key,
    required this.hintText,
    required this.inputType,
    required this.labelText2,
    required this.secure1,
    required this.capital,
    required this.nameController1,
    //required this.icon
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
      padding: const EdgeInsets.only(
        left: 10,
      ),
      child: TextFormField(
        //maxLines: 5,
        maxLength: 35,
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
