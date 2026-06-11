import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../providers/chat_provider.dart';
import '../../../../core/services/cloudinary_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String receiverId;
  final String senderId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.senderId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  String _uploadStatus = '';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _sending = true;
      _uploadStatus = 'Uploading Image...';
    });

    try {
      final file = File(picked.path);
      final url = await CloudinaryService().uploadImage(file);
      if (url != null) {
        final repo = ref.read(chatRepositoryProvider);
        await repo.sendAttachmentMessage(
          conversationId: widget.conversationId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          fileUrl: url,
          fileType: 'image',
          fileName: picked.name,
        );
        _scrollToBottom();
      } else {
        _snack('Image upload failed.');
      }
    } catch (e) {
      _snack('Error uploading image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _sending = true;
      _uploadStatus = 'Uploading Video...';
    });

    try {
      final file = File(picked.path);
      final url = await CloudinaryService().uploadVideo(file);
      if (url != null) {
        final repo = ref.read(chatRepositoryProvider);
        await repo.sendAttachmentMessage(
          conversationId: widget.conversationId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          fileUrl: url,
          fileType: 'video',
          fileName: picked.name,
        );
        _scrollToBottom();
      } else {
        _snack('Video upload failed.');
      }
    } catch (e) {
      _snack('Error uploading video: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _sendMockPdf() async {
    setState(() {
      _sending = true;
      _uploadStatus = 'Attaching Document...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final repo = ref.read(chatRepositoryProvider);
      // Beautiful mock pdf tenancy draft url
      const pdfUrl = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';
      await repo.sendAttachmentMessage(
        conversationId: widget.conversationId,
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        fileUrl: pdfUrl,
        fileType: 'pdf',
        fileName: 'Tenancy_Agreement_Draft.pdf',
      );
      _scrollToBottom();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Send Attachment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachmentTile(
                    icon: Icons.image_rounded,
                    color: Colors.blue,
                    label: 'Image',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage();
                    },
                  ),
                  _attachmentTile(
                    icon: Icons.video_library_rounded,
                    color: Colors.green,
                    label: 'Video',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendVideo();
                    },
                  ),
                  _attachmentTile(
                    icon: Icons.picture_as_pdf_rounded,
                    color: Colors.red,
                    label: 'PDF Doc',
                    onTap: () {
                      Navigator.pop(context);
                      _sendMockPdf();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAvatar(String userId, String defaultLetter, {bool isMe = false}) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final photoUrl = data?['photoUrl'] as String?;
        final name = data?['fullName'] as String? ?? defaultLetter;
        final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return CircleAvatar(
          radius: 16,
          backgroundColor: isMe
              ? const Color(0xFF10B981).withValues(alpha: 0.15)
              : const Color(0xFF6366F1).withValues(alpha: 0.15),
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl == null || photoUrl.isEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMe ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                  ),
                )
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(chatRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.receiverId)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final name = data?['fullName'] ?? data?['name'] ?? 'Chat';
            final photoUrl = data?['photoUrl'] as String?;

            return Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Secure Connection',
                        style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: repo.watchMessages(
                conversationId: widget.conversationId,
                limit: 50,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];

                // messages are ordered desc; show in asc for UI
                final ordered = docs.toList()
                  ..sort((a, b) {
                    final at = a.data()['sentAt'];
                    final bt = b.data()['sentAt'];
                    if (at is Timestamp && bt is Timestamp) {
                      return at.compareTo(bt);
                    }
                    return 0;
                  });

                if (ordered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No messages yet.\nSay hello!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: ordered.length,
                  itemBuilder: (context, index) {
                    final data = ordered[index].data();
                    final senderId = data['senderId'] as String? ?? '';
                    final text = data['message']?.toString() ?? '';
                    final messageType = data['messageType'] as String? ?? 'text';
                    final fileUrl = data['fileUrl'] as String? ?? '';
                    final fileName = data['fileName'] as String? ?? '';
                    final isMe = senderId == widget.senderId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            _buildAvatar(widget.receiverId, 'R'),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: messageType == 'text'
                                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                  : const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF6366F1)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                                border: isMe ? null : Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _buildMessageContent(
                                type: messageType,
                                text: text,
                                fileUrl: fileUrl,
                                fileName: fileName,
                                isMe: isMe,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            _buildAvatar(widget.senderId, 'S', isMe: true),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_sending && _uploadStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.white,
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _uploadStatus,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1), size: 26),
                    onPressed: _showAttachmentOptions,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                        )
                      : CircleAvatar(
                          backgroundColor: const Color(0xFF6366F1),
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            onPressed: () async {
                              final message = _controller.text.trim();
                              if (message.isEmpty) return;
                              if (widget.senderId != FirebaseAuth.instance.currentUser?.uid) return;

                              setState(() => _sending = true);
                              try {
                                await repo.sendTextMessage(
                                  conversationId: widget.conversationId,
                                  senderId: widget.senderId,
                                  receiverId: widget.receiverId,
                                  message: message,
                                );
                                _controller.clear();
                                _scrollToBottom();
                              } finally {
                                if (mounted) {
                                  setState(() => _sending = false);
                                }
                              }
                            },
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

  Widget _buildMessageContent({
    required String type,
    required String text,
    required String fileUrl,
    required String fileName,
    required bool isMe,
  }) {
    final textStyle = TextStyle(
      color: isMe ? Colors.white : Colors.black87,
      fontSize: 14.5,
      height: 1.35,
    );

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            if (fileUrl.isNotEmpty) {
              final uri = Uri.parse(fileUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 220),
            child: Image.network(
              fileUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 150,
                  height: 150,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                width: 150,
                height: 150,
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    } else if (type == 'video') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            if (fileUrl.isNotEmpty) {
              final uri = Uri.parse(fileUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            width: 200,
            height: 130,
            color: Colors.black87,
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.video_library_rounded, color: Colors.white54, size: 42),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: Icon(Icons.play_arrow_rounded, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (type == 'pdf') {
      return InkWell(
        onTap: () async {
          if (fileUrl.isNotEmpty) {
            final uri = Uri.parse(fileUrl);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          width: 220,
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.isNotEmpty ? fileName : 'Agreement.pdf',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PDF Document',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Text(text, style: textStyle);
    }
  }
}
