import 'package:flutter/material.dart';
import 'package:tasteturner/constants.dart';
import 'package:tasteturner/helper/utils.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final bool canUseAI;
  final VoidCallback onSend;
  final VoidCallback onImagePick;
  final VoidCallback onVoiceToggle;
  final bool isPlanning;
  final bool isReadyToGenerate;
  final VoidCallback onGeneratePlan;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isListening,
    required this.canUseAI,
    required this.onSend,
    required this.onImagePick,
    required this.onVoiceToggle,
    this.isPlanning = false,
    this.isReadyToGenerate = false,
    required this.onGeneratePlan,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

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
            // Camera Button
            _buildIconButton(
              context,
              icon: Icons.camera_alt_outlined,
              onTap: canUseAI ? onImagePick : null,
              tooltip: 'Send Image',
            ),
            SizedBox(width: getPercentageWidth(2, context)),

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
                      child: TextField(
                        controller: controller,
                        maxLines: 5,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText:
                              isListening ? 'Listening...' : 'Ask Buddy...',
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
                        onSubmitted: (_) => canUseAI ? onSend() : null,
                      ),
                    ),
                    // Voice Button inside the pill
                    GestureDetector(
                      onTap: canUseAI ? onVoiceToggle : null,
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

            // Send / Generate Button
            if (isPlanning && isReadyToGenerate)
              _buildGenerateButton(context)
            else
              _buildSendButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.primary.withOpacity(0.1)
                : theme.disabledColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isEnabled ? theme.colorScheme.primary : theme.disabledColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = controller.text.trim().isNotEmpty;
    final isEnabled = canUseAI && hasText;

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
  }

  Widget _buildGenerateButton(BuildContext context) {
    return Material(
      color: kAccent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onGeneratePlan,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Generate',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
