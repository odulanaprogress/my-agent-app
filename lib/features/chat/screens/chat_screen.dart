import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../repositories/chat_repository.dart';
import 'package:agent_app/core/widgets/app_loader.dart';


class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository repository = ChatRepository();
  final TextEditingController messageController = TextEditingController();

  final currentUser = FirebaseAuth.instance.currentUser;

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await repository.sendMessage(receiverId: widget.receiverId, message: text);
      messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'block') {
                await repository.blockUser(widget.receiverId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked.')),
                  );
                }
              } else if (value == 'delete') {
                await repository.deleteChat(widget.receiverId);
                if (context.mounted) {
                  Navigator.pop(context); // Go back after deleting chat
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat deleted.')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'block',
                child: Text('Block User'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Chat'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: repository.getMessages(widget.receiverId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: AppLoader(size: 24));
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser?.uid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          message.message,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    child: IconButton(
                      onPressed: sendMessage,
                      icon: const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
