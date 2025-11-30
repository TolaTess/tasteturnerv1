import 'package:flutter/material.dart';
import 'package:tasteturner/constants.dart';

class ChatModeSwitcher extends StatefulWidget {
  final TabController controller;
  final List<ChatModeTab> tabs;
  final bool? isDarkMode;

  const ChatModeSwitcher({
    super.key,
    required this.controller,
    required this.tabs,
    this.isDarkMode,
  });

  @override
  State<ChatModeSwitcher> createState() => _ChatModeSwitcherState();
}

class _ChatModeSwitcherState extends State<ChatModeSwitcher> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode =
        widget.isDarkMode ?? (theme.brightness == Brightness.dark);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kAccentLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Animated Indicator
          AnimatedAlign(
            alignment: Alignment(
              -1.0 + (widget.controller.index / (widget.tabs.length - 1)) * 2.0,
              0,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / widget.tabs.length,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab Items
          Row(
            children: List.generate(widget.tabs.length, (index) {
              final isSelected = widget.controller.index == index;
              final tab = widget.tabs[index];

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.controller.animateTo(index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : kDarkGrey.withOpacity(0.6)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDarkMode
                                    ? Colors.white.withOpacity(0.6)
                                    : kDarkGrey.withOpacity(0.6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class ChatModeTab {
  final IconData icon;
  final String label;

  const ChatModeTab({
    required this.icon,
    required this.label,
  });
}
