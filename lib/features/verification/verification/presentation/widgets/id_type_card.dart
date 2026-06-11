import 'package:flutter/material.dart';

class IdTypeCard extends StatelessWidget {
  const IdTypeCard({super.key, required this.title, this.selected = false});

  final String title;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.black : Colors.white;
    final fg = selected ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
          if (selected)
            Icon(
              Icons.check_circle,
              size: 18,
              color: Colors.white.withValues(alpha: 0.95),
            ),
        ],
      ),
    );
  }
}
