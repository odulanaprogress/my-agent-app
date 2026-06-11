import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai_service.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showTicketButton = false;

  // Local rule-based fallback answers for company info
  static const Map<String, String> _localAnswers = {
    'contact': 'You can reach AGENT support at agentcustomercare@gmail.com or use the Support button on your dashboard.',
    'phone': 'AGENT Real Estate Platform support email: agentcustomercare@gmail.com.',
    'address': 'AGENT operates across Nigeria. Use our platform to explore properties in your preferred state.',
    'payment': 'All payments on AGENT are processed through Paystack and held in Escrow until you take possession of the property.',
    'escrow': 'Our Escrow system ensures the landlord only receives payment once you take possession. This protects both tenant and landlord.',
    'refund': 'Refund requests are handled through our support team. Please open a support ticket for assistance.',
    'verify': 'To get verified, go to your Profile and upload your NIN, government ID or utility bill.',
    'kyc': 'KYC (Know Your Customer) verification requires your NIN + government-issued ID. Upload them in the Verification section.',
    'rent': 'You can browse, filter, and pay for rental properties directly through the AGENT platform.',
    'sell': 'Landlords can list properties for Sale, Rent, Lease, or Shortlet from their dashboard.',
    'shortlet': 'Shortlet properties are available for short-term stays. Browse the shortlet category on your dashboard.',
    'lease': 'Lease listings offer longer-term arrangements. Check the Lease category in property search.',
    'cancel': 'To cancel a booking or property request, open a support ticket so our team can assist you.',
    'dispute': 'For disputes between tenants and landlords, please open a support ticket and we will mediate.',
    'inspection': 'Property inspections can be scheduled by messaging the landlord via our in-app chat.',
    'agreement': 'Digital tenancy agreements are available on AGENT. Access them from the payment or booking confirmation page.',
    'wallet': 'Your AGENT wallet holds your available balance. Payments are held in escrow and released upon possession.',
    'hello': 'Hello! I\'m AGENT AI Assistant. How can I help you today? Ask me about properties, payments, verification, or open a support ticket.',
    'hi': 'Hi there! I\'m AGENT AI. How can I assist you today?',
    'help': 'I can help with: property search, payment questions, verification, support tickets, landlord features, and more. What do you need?',
  };

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text: '👋 Hello! I\'m AGENT AI Assistant.\n\nI can help you with:\n• Property search & inquiries\n• Payment & escrow questions\n• KYC verification guidance\n• Landlord & tenant features\n• Open a support ticket\n\nHow can I help you today?',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _matchLocalAnswer(String input) {
    final lower = input.toLowerCase();
    for (final kv in _localAnswers.entries) {
      if (lower.contains(kv.key)) return kv.value;
    }
    return null;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    // Check for support ticket triggers
    final lower = text.toLowerCase();
    final tickerTriggers = ['ticket', 'complaint', 'escalate', 'speak to agent', 'human', 'support agent'];
    if (tickerTriggers.any(lower.contains)) {
      setState(() {
        _showTicketButton = true;
        _isLoading = false;
        _messages.add(_ChatMessage(
          text: 'I understand you\'d like to speak with our support team. You can open a support ticket by tapping the button below, and a customer care agent will respond shortly.',
          isUser: false,
          timestamp: DateTime.now(),
          isSystem: true,
        ));
      });
      _scrollToBottom();
      return;
    }

    // Try local rule-based answer first
    final localAnswer = _matchLocalAnswer(text);
    if (localAnswer != null) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: localAnswer,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    // Try AI service
    try {
      final response = await _aiService.sendMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: 'I\'m sorry, I couldn\'t process your request right now. Would you like to open a support ticket so a human agent can assist you?',
          isUser: false,
          timestamp: DateTime.now(),
          isSystem: true,
        ));
        _showTicketButton = true;
        _isLoading = false;
      });
    }

    _scrollToBottom();
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

  Future<void> _openSupportTicket() async {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Open Support Ticket',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Describe your issue...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    final subject = subjectController.text.trim();
                    final message = messageController.text.trim();
                    if (subject.isEmpty || message.isEmpty) return;

                    // Get user data from Firestore
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();
                    final userData = userDoc.data();

                    await FirebaseFirestore.instance
                        .collection('support_tickets')
                        .add({
                      'userId': user.uid,
                      'userName': userData?['fullName'] ?? 'Unknown',
                      'userEmail': user.email ?? '',
                      'subject': subject,
                      'message': message,
                      'status': 'open',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (ctx.mounted) Navigator.pop(ctx);

                    if (mounted) {
                      setState(() {
                        _messages.add(_ChatMessage(
                          text: '✅ Your support ticket has been submitted! Our team will respond to you shortly at ${user.email}.',
                          isUser: false,
                          timestamp: DateTime.now(),
                          isSystem: true,
                        ));
                        _showTicketButton = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ticket submitted successfully!'),
                          backgroundColor: Color(0xFF6366F1),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AGENT AI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Support Assistant',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openSupportTicket,
            icon: const Icon(Icons.confirmation_number_outlined,
                color: Colors.white, size: 18),
            label: const Text('Ticket',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _dot(0),
                        _dot(1),
                        _dot(2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_showTicketButton)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                label: const Text('Open Support Ticket'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: _openSupportTicket,
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Ask AGENT AI anything...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF6366F1),
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: _isLoading ? null : _sendMessage,
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

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: msg.isSystem
                  ? Colors.orange.shade100
                  : const Color(0xFF6366F1).withValues(alpha: 0.15),
              child: Icon(
                msg.isSystem ? Icons.info_outline : Icons.smart_toy_rounded,
                size: 16,
                color: msg.isSystem ? Colors.orange : const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? const Color(0xFF6366F1)
                    : msg.isSystem
                        ? Colors.orange.shade50
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: msg.isUser
                      ? Colors.white
                      : msg.isSystem
                          ? Colors.orange.shade900
                          : Colors.black87,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isSystem;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isSystem = false,
  });
}
