import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'api.dart';

void main() {
  runApp(const MyApp());
}

// A dialog page, with a text field for input and a button to send message, and a list view to show the messages both from user and the bot
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // text controller for the text field
  final TextEditingController _textController = TextEditingController();

  // list of messages
  final List<ChatMessage> _messages = [];

  // use a persistent storage to store the messages, and load the messages from the storage when the page is created, and save the messages to the storage when the page is destroyed
  @override
  void initState() {
    super.initState();

    // load messages from storage
    _loadMessages();
  }

  // save messages to storage
  @override
  void dispose() {
    super.dispose();

    // save messages to storage
    _saveMessages();
  }

  // save messages to storage
  void _saveMessages() {
    // first, serialize the list of messages to a string
    var string = jsonEncode(_messages);

    // then, save the string to a sqlite database
    _save(string);
  }

  // save
  void _save(String string) {
    // save string to sqlite database
    final File file = File('messages.txt');
    // create file if not exists
    if (!file.existsSync()) {
      // if any exception occurs, the app will crash, so we need to handle the exception
      try {
        // if any parent directory does not exist, it will be created
        file.createSync(recursive: true);
      } catch (e) {
        print(e);
      }
    }
    file.writeAsStringSync(string);
  }

  // load messages from storage
  void _loadMessages() {
    // load messages from storage, use json decode to convert the string to a list.
    _load().then((String string) {
      // if the string is empty, return
      if (string.isEmpty) {
        return;
      }

      // convert string to list
      final List<dynamic> list = jsonDecode(string);

      // convert list to messages
      final List<ChatMessage> messages =
          list.map((dynamic item) => ChatMessage.fromJson(item)).toList();

      // set messages
      setState(() {
        _messages.addAll(messages);
      });
    });
  }

  // load
  Future<String> _load() async {
    // load string from sqlite database
    final File file = File('messages.txt');
    if (!file.existsSync()) {
      return '';
    }
    return file.readAsString();
  }

  // api
  final ChatApi _api = ChatApi('');

  // send message
  void _sendMessage(String message) {
    // clear text field
    _textController.clear();

    // add message to list
    setState(() {
      _messages.add(ChatMessage(message, true));
    });

    // request with message
    _api.requestWithMessage(message, 'user').then((ChatResponse response) {
      // add response to list
      setState(() {
        _messages.add(ChatMessage(response.message, false));
      });
    });
  }

  // retry message
  void _retryMessage(ChatMessage message) {
    // remove message from list
    setState(() {
      _messages.remove(message);
    });

    // request with message
    _api.requestWithMessage(message.message, 'user', true).then(
      (ChatResponse response) {
        // add response to list
        setState(() {
          _messages.add(ChatMessage(response.message, false));
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          // list view
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                // get message
                final ChatMessage message = _messages[index];

                // return message widget
                return ChatMessageWidget(
                  message: message,
                  onRetry: () => _retryMessage(message),
                );
              },
            ),
          ),
          // text field
          Container(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // text field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Enter message',
                    ),
                  ),
                ),
                // send button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// A widget to show a message, a message should have a icon to indicator if it is from user or the bot, and a text to show the message, and a retry button if the message is from the bot
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({
    Key? key,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  // message
  final ChatMessage message;

  // on retry
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // return message widget, the widget may overflow, so we use a row to wrap it

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: message.isFromUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // message widget
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: message.isFromUser ? Colors.blue : Colors.grey,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // icon
                Icon(
                  message.isFromUser ? Icons.person : Icons.chat,
                  color: Colors.white,
                ),
                // message
                Text(
                  message.message,
                  style: const TextStyle(color: Colors.white),
                ),
                // retry button
                if (!message.isFromUser)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// A message
class ChatMessage {
  // message
  final String message;

  // is from user
  final bool isFromUser;

  // constructor
  ChatMessage(this.message, this.isFromUser);

  // from json
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      json['message'] as String,
      json['isFromUser'] as bool,
    );
  }
}

// MyApp
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatPage(),
    );
  }
}
