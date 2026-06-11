import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view chats')),
      );
    }

    final repo = ref.read(chatRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: StreamBuilder<List<String>>(
        stream: repo.watchConversationIdsForUser(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ids = snap.data ?? [];

          if (ids.isEmpty) {
            return const Center(
              child: Text('Start exploring properties to chat.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final conversationId = ids[index];
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: repo.conversations.doc(conversationId).get(),
                builder: (context, propSnap) {
                  final data = propSnap.data?.data();
                  final lastMessage = (data?['lastMessage'] ?? '').toString();
                  final propertyId = (data?['propertyId'] ?? '').toString();
                  final participants =
                      (data?['participants'] as List?)?.cast<String>() ?? [];
                  final otherUid = participants.firstWhere(
                    (p) => p != uid,
                    orElse: () => '',
                  );

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('properties')
                        .doc(propertyId)
                        .snapshots(),
                    builder: (context, propertySnap) {
                      final propData = propertySnap.data?.data();
                      final propertyTitle =
                          propData?['title'] ?? 'Property Chat';
                      final propertyImageList =
                          (propData?['imageUrls'] as List?);
                      final propertyImage = (propData?['imageUrl'] as String?) ??
                          (propData?['image'] as String?) ??
                          (propertyImageList != null && propertyImageList.isNotEmpty
                              ? propertyImageList[0].toString()
                              : '');

                      return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUid)
                            .snapshots(),
                        builder: (context, userSnap) {
                          final userData = userSnap.data?.data();
                          final otherName = userData?['fullName'] ??
                              userData?['name'] ??
                              'User';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: propertyImage.toString().isNotEmpty
                                    ? Image.network(
                                        propertyImage.toString(),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, st) => Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey.shade100,
                                          child: const Icon(Icons.home_work),
                                        ),
                                      )
                                    : Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey.shade100,
                                        child: const Icon(Icons.home_work),
                                      ),
                              ),
                              title: Text(
                                propertyTitle.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'With $otherName',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lastMessage.isEmpty
                                        ? 'No messages yet'
                                        : lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      conversationId: conversationId,
                                      senderId: uid,
                                      receiverId: otherUid,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
