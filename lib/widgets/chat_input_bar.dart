import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/constants.dart';
import 'package:tasteturner/helper/utils.dart';
import 'package:tasteturner/service/buddy_chat_controller.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isListening;
  final bool canUseAI;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onImagePick;
  final VoidCallback onVoiceToggle;

  const ChatInputBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.isListening,
    required this.canUseAI,
    this.enabled = true,
    required this.onSend,
    required this.onImagePick,
    required this.onVoiceToggle,
  });

  String _getLoadingPlaceholder(String mode, bool isResponding) {
    if (!enabled && mode.toLowerCase() == 'meal') {
      return 'Select an option above or click "Type my own request"';
    }
    if (!isResponding) return 'Ask Turner...';

    final loadingMessages = {
      'sous chef': [
        'Tasting...',
        'Analyzing...',
        'Thinking...',
        'Preparing...',
      ],
      'meal': [
        'Cooking...',
        'Planning...',
        'Creating...',
        'Designing...',
      ],
    };

    final messages =
        loadingMessages[mode.toLowerCase()] ?? loadingMessages['sous chef']!;
    // Rotate through messages based on time to show activity
    final index =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) % messages.length;
    return messages[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Get chat controller to access loading state and mode
    // ChatInputBar is only used in buddy_screen.dart, so it uses BuddyChatController
    final chatController = Get.find<BuddyChatController>();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1.5, context),
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Camera Button removed - now in meal plan quick actions
            // Main Input Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? kLightGrey.withOpacity(0.1)
                      : kLightGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDarkMode
                        ? kWhite.withOpacity(0.1)
                        : kBlack.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Obx(() {
                        final isResponding = chatController.isResponding.value;
                        final currentMode = chatController.currentMode.value;
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: 5,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.bodyMedium,
                          enabled: enabled &&
                              !isResponding, // Disable input if not enabled or while responding
                          decoration: InputDecoration(
                            hintText: isListening
                                ? 'Listening...'
                                : _getLoadingPlaceholder(
                                    currentMode, isResponding),
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(4, context),
                              vertical: getPercentageHeight(1.2, context),
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) =>
                              enabled && canUseAI && !isResponding
                                  ? onSend()
                                  : null,
                        );
                      }),
                    ),
                    // Voice Button inside the pill
                    GestureDetector(
                      onTap: enabled && canUseAI ? onVoiceToggle : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isListening
                              ? kRed.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isListening ? Icons.mic : Icons.mic_none_outlined,
                          color: isListening
                              ? kRed
                              : theme.iconTheme.color?.withOpacity(0.6),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: getPercentageWidth(2, context)),

            // Send Button
            _buildSendButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final theme = Theme.of(context);
    // ChatInputBar is only used in buddy_screen.dart, so it uses BuddyChatController
    final chatController = Get.find<BuddyChatController>();
    return Obx(() {
      final hasText = controller.text.trim().isNotEmpty;
      final isResponding = chatController.isResponding.value;
      final isEnabled = enabled && canUseAI && hasText && !isResponding;

      return Material(
        color: isEnabled ? kAccent : theme.disabledColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isEnabled ? onSend : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    });
  }
}
