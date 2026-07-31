import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/chat_provider.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../auth/presentation/providers/current_user_provider.dart';
import '../../data/chat_repository.dart';

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

  // Track upload status for files only (NOT text messages)
  bool _isUploading = false;
  String _uploadStatus = '';

  // Voice Recording — tap to start / tap to stop
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;

  // Audio Playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;

  // Text state for mic/send button swap
  bool _isTextEmpty = true;

  // Swipe to reply
  String? _replyToId;
  String? _replyToText;
  String? _replyToSender;

  // Track last message count to detect new messages
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _controller.addListener(() {
      setState(() {
        _isTextEmpty = _controller.text.trim().isEmpty;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _currentlyPlayingUrl = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Tap to START recording
  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
        });
      } else {
        _snack('Microphone permission required.');
      }
    } catch (e) {
      _snack('Error starting recording: $e');
    }
  }

  /// Tap to STOP recording and send
  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        await _uploadAndSendVoice(File(path));
      }
    } catch (e) {
      _snack('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
    } catch (_) {
      // Ignore errors when cancelling — recording may have already stopped
    }
  }

  Future<void> _uploadAndSendVoice(File file) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading voice...';
    });
    try {
      final url = await CloudinaryService().uploadVideo(file);
      if (url != null) {
        final repo = ref.read(chatRepositoryProvider);
        await repo.sendVoiceMessage(
          conversationId: widget.conversationId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          fileUrl: url,
          durationStr: 'Audio',
          replyToId: _replyToId,
          replyToText: _replyToText,
          replyToSender: _replyToSender,
        );
        _cancelReply();
        _scrollToBottom();
      } else {
        _snack('Voice upload failed.');
      }
    } catch (e) {
      _snack('Error uploading voice: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToText = null;
      _replyToSender = null;
    });
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading image...';
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
          _isUploading = false;
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
      _isUploading = true;
      _uploadStatus = 'Uploading video...';
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
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Future<void> _sendMockPdf() async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Attaching document...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final repo = ref.read(chatRepositoryProvider);
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
          _isUploading = false;
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

  void _handleCloseTicket(BuildContext context, ChatRepository repo) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: AppLoader(size: 56)),
      );
      final messagesSnap = await repo.watchMessages(conversationId: widget.conversationId, limit: 100).first;
      final msgs = messagesSnap.docs.map((d) {
        final data = d.data();
        final text = data['message'] ?? '';
        final sender = data['senderId'] == widget.senderId ? 'Agent' : 'User';
        return '\\n$sender: $text';
      }).toList().reversed.join('');

      await repo.closeTicket(widget.conversationId, msgs);
      if (context.mounted) Navigator.pop(context);

      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        query: 'subject=Support Ticket Closed&body=Transcript:$msgs',
      );
      launchUrl(emailLaunchUri);
      if (context.mounted) _snack('Ticket closed.');
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _snack('Error closing ticket: $e');
      }
    }
  }

  List<Widget> _buildAppBarActions(BuildContext context, ChatRepository repo, Map<String, dynamic>? convData, String? role) {
    final blockedBy = convData?['blockedBy'] as List<dynamic>? ?? [];
    final isClosed = convData?['isClosed'] == true;
    final didIBlock = blockedBy.contains(widget.senderId);

    return [
      PopupMenuButton<String>(
        onSelected: (val) async {
          if (val == 'delete') {
            await repo.deleteChat(widget.conversationId, widget.senderId);
            if (context.mounted) context.pop();
          } else if (val == 'block') {
            await repo.toggleBlockUser(widget.conversationId, widget.senderId, !didIBlock);
          } else if (val == 'close') {
            _handleCloseTicket(context, repo);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'delete', child: Text('Delete Chat')),
          PopupMenuItem(
            value: 'block',
            child: Text(didIBlock ? 'Unblock User' : 'Block User'),
          ),
          if (!isClosed && (role == 'admin' || role == 'customer_support'))
            const PopupMenuItem(value: 'close', child: Text('Close Ticket')),
        ],
      )
    ];
  }

  /// Sends a text message instantly without blocking the UI
  void _sendTextMessage(ChatRepository repo) {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    if (widget.senderId != FirebaseAuth.instance.currentUser?.uid) return;

    // Clear immediately for snappy UX — fire and forget
    _controller.clear();
    final replyId = _replyToId;
    final replyText = _replyToText;
    final replySender = _replyToSender;
    _cancelReply();

    repo.sendTextMessage(
      conversationId: widget.conversationId,
      senderId: widget.senderId,
      receiverId: widget.receiverId,
      message: message,
      replyToId: replyId,
      replyToText: replyText,
      replyToSender: replySender,
    ).catchError((e) {
      _snack('Failed to send: $e');
    });

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(chatRepositoryProvider);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).snapshots(),
      builder: (context, convSnap) {
        final convData = convSnap.data?.data();
        final isClosed = convData?['isClosed'] == true;
        final blockedBy = convData?['blockedBy'] as List<dynamic>? ?? [];
        final isBlocked = blockedBy.isNotEmpty;
        final currentUser = ref.read(currentUserProvider);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            actions: _buildAppBarActions(context, repo, convData, currentUser?.role),
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
                    // Show nothing (empty space) while initial data loads — no spinner
                    if (!snap.hasData) {
                      return const SizedBox.shrink();
                    }

                    final docs = snap.data?.docs ?? [];

                    // Sort ascending by sentAt for correct display order
                    final ordered = docs.toList()
                      ..sort((a, b) {
                        final at = a.data()['sentAt'];
                        final bt = b.data()['sentAt'];
                        if (at is Timestamp && bt is Timestamp) {
                          return at.compareTo(bt);
                        }
                        return 0;
                      });

                    // Auto-scroll to bottom when new messages arrive
                    if (ordered.length != _lastMessageCount) {
                      _lastMessageCount = ordered.length;
                      _scrollToBottom();
                    }

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

                        final replyToText = data['replyToText'] as String?;
                        final replyToSender = data['replyToSender'] as String?;
                        final type = messageType;

                        return Dismissible(
                          key: Key(ordered[index].id),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            setState(() {
                              _replyToId = ordered[index].id;
                              _replyToText = type == 'text' ? text : '[$type]';
                              _replyToSender = isMe ? 'You' : 'User';
                            });
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.transparent,
                            child: const Icon(Icons.reply_rounded, color: Color(0xFF6366F1)),
                          ),
                          child: Padding(
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
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (replyToText != null)
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border(left: BorderSide(color: isMe ? Colors.white : const Color(0xFF6366F1), width: 3)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(replyToSender ?? 'User', style: TextStyle(color: isMe ? Colors.white : const Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 11)),
                                                const SizedBox(height: 2),
                                                Text(replyToText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        _buildMessageContent(
                                          type: messageType,
                                          text: text,
                                          fileUrl: fileUrl,
                                          fileName: fileName,
                                          isMe: isMe,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  _buildAvatar(widget.senderId, 'S', isMe: true),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Upload progress bar — only shown for file/voice uploads, not text
              if (_isUploading && _uploadStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppLoader(size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _uploadStatus,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                ),

              if (isClosed || isBlocked)
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Text(
                      isClosed ? 'This ticket is closed.' : 'Action not allowed.',
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    if (_replyToText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: const Border(left: BorderSide(color: Color(0xFF6366F1), width: 4)),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Replying to ${_replyToSender ?? 'User'}', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(_replyToText!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: _cancelReply,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          ],
                        ),
                      ),

                    // Recording indicator bar
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: Colors.red.shade50,
                        child: Row(
                          children: [
                            const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Recording... Tap the stop button to send',
                                style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            GestureDetector(
                              onTap: _cancelRecording,
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
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
                            if (!_isRecording)
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
                                  enabled: !_isRecording,
                                  decoration: InputDecoration(
                                    hintText: _isRecording ? 'Recording audio...' : 'Type a message...',
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Mic / Stop / Send button — no loading spinner for text messages
                            _isTextEmpty
                                ? GestureDetector(
                                    onTap: _isRecording
                                        ? _stopRecordingAndSend
                                        : _startRecording,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: _isRecording ? 48 : 40,
                                      height: _isRecording ? 48 : 40,
                                      decoration: BoxDecoration(
                                        color: _isRecording ? Colors.red : const Color(0xFF6366F1),
                                        shape: BoxShape.circle,
                                        boxShadow: _isRecording
                                            ? [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                                            : [],
                                      ),
                                      child: Icon(
                                        _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                                        color: Colors.white,
                                        size: _isRecording ? 26 : 20,
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: () => _sendTextMessage(repo),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF6366F1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
                  child: Center(child: AppLoader(size: 40)),
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
    } else if (type == 'audio') {
      final isPlaying = _currentlyPlayingUrl == fileUrl && _isPlaying;
      return Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isMe ? Colors.white : const Color(0xFF6366F1),
              radius: 18,
              child: IconButton(
                icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: isMe ? const Color(0xFF6366F1) : Colors.white, size: 20),
                onPressed: () async {
                  if (isPlaying) {
                    await _audioPlayer.pause();
                  } else {
                    await _audioPlayer.play(UrlSource(fileUrl));
                    setState(() {
                      _currentlyPlayingUrl = fileUrl;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withValues(alpha: 0.3) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: isPlaying ? 0.5 : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white : const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Audio', style: TextStyle(color: isMe ? Colors.white70 : Colors.grey.shade600, fontSize: 10)),
          ],
        ),
      );
    } else {
      return Text(text, style: textStyle);
    }
  }
}
