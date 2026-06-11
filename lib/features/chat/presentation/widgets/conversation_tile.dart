import 'package:flutter/material.dart';

class ConversationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(title), subtitle: Text(subtitle), onTap: onTap);
  }
}
