import 'package:flutter/material.dart';
import '../theme.dart';

// =======================
// ❤️ REACTION PICKER & DISPLAY
// =======================
class ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;
  const ReactionPicker({super.key, required this.onReactionSelected});
  static const reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏', '🔥', '👏'];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: reactions
              .map(
                (emoji) => GestureDetector(
                  onTap: () => onReactionSelected(emoji),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 24,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class ReactionsDisplay extends StatelessWidget {
  final Map<String, dynamic>? reactions;
  final String currentUsername;
  final Function(String) onReactionTap;
  const ReactionsDisplay({
    super.key,
    this.reactions,
    required this.currentUsername,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions == null || reactions!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Wrap(
        spacing: 2,
        runSpacing: 3,
        children: reactions!.entries.map((entry) {
          final emoji = entry.key;
          final users = List<String>.from(entry.value);
          // final hasMyReaction = users.contains(currentUsername); // Можна використати для підсвітки
          return GestureDetector(
            onTap: () => onReactionTap(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (users.length > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${users.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
