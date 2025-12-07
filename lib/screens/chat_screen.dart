import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../service/chat_controller.dart';

import '../widgets/icon_widget.dart';
import '../widgets/chat_item.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? friendId;
  final String? screen;
  final Map<String, dynamic>? dataSrc;
  final UserModel? friend;

  const ChatScreen({
    super.key,
    this.chatId,
    this.friendId,
    this.dataSrc,
    this.screen,
    this.friend,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();
  late final ChatController chatController;

  late String? chatId;
  @override
  void initState() {
    super.initState();
    // Initialize ChatController
    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      // If controller is not found, initialize it
      chatController = Get.put(ChatController());
    }

    chatId = widget.chatId;

    if (chatId != null && chatId!.isNotEmpty) {
      try {
        // Ensure we're using friend chat mode
        chatController.chatId = chatId!;
        chatController.listenToFriendMessages();
        if (widget.friendId != null && widget.friendId!.isNotEmpty) {
          chatController.markMessagesAsRead(chatId!, widget.friendId!);
        }

        if (widget.dataSrc != null && widget.dataSrc!.isNotEmpty) {
          if (widget.dataSrc?['screen'] == 'meal_design') {
            _handleCalendarShare(widget.dataSrc!);
          } else if (widget.screen == 'share_recipe' ||
              widget.dataSrc?['screen'] == 'share_recipe') {
            // Wait a bit for messages to load, then check and share
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              // Check if this recipe was already shared in this chat
              final mealId = widget.dataSrc?['mealId'] ?? '';
              final alreadyShared = _checkIfRecipeAlreadyShared(mealId);
              if (alreadyShared) {
              } else {
                // Handle recipe sharing - check for image or share without image
                final mediaPaths = widget.dataSrc?['mediaPaths'];
                final image = widget.dataSrc?['image'];
                if (mediaPaths != null &&
                    mediaPaths is List &&
                    mediaPaths.isNotEmpty) {
                  _shareImage(mediaPaths[0]);
                } else if (image != null &&
                    image is String &&
                    image.isNotEmpty) {
                  _shareImage(image);
                } else {
                  // Share recipe without image
                  _shareRecipeWithoutImage();
                }
              }
            });
          } else if (widget.dataSrc?['mediaPaths'] != null) {
            final mediaPaths = widget.dataSrc?['mediaPaths'];
            if (mediaPaths is List && mediaPaths.isNotEmpty) {
              _shareImage(mediaPaths[0] ?? widget.dataSrc?['image']);
            } else if (widget.dataSrc?['image'] != null) {
              _shareImage(widget.dataSrc?['image']);
            }
          } else if (widget.dataSrc?['image'] != null) {
            _shareImage(widget.dataSrc?['image']);
          } else {}
        } else {}
      } catch (e) {
        debugPrint('Error initializing chat with chatId: $e');
      }
    } else if (widget.friendId != null && widget.friendId!.isNotEmpty) {
      chatController.initializeFriendChat(widget.friendId!).then((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          chatId = chatController.chatId;
        });
        if (widget.friendId != null && widget.friendId!.isNotEmpty) {
          chatController.markMessagesAsRead(chatId!, widget.friendId!);
        }

        if (widget.dataSrc != null && widget.dataSrc!.isNotEmpty) {
          if (widget.dataSrc?['screen'] == 'meal_design') {
            _handleCalendarShare(widget.dataSrc!);
          } else if (widget.screen == 'share_recipe' ||
              widget.dataSrc?['screen'] == 'share_recipe') {
            // Wait a bit for messages to load, then check and share
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              // Check if this recipe was already shared in this chat
              final mealId = widget.dataSrc?['mealId'] ?? '';
              final alreadyShared = _checkIfRecipeAlreadyShared(mealId);
              if (alreadyShared) {
              } else {
                // Handle recipe sharing - check for image or share without image
                final mediaPaths = widget.dataSrc?['mediaPaths'];
                final image = widget.dataSrc?['image'];
                if (mediaPaths != null &&
                    mediaPaths is List &&
                    mediaPaths.isNotEmpty) {
                  _shareImage(mediaPaths[0]);
                } else if (image != null &&
                    image is String &&
                    image.isNotEmpty) {
                  _shareImage(image);
                } else {
                  // Share recipe without image
                  _shareRecipeWithoutImage();
                }
              }
            });
          } else if (widget.dataSrc?['mediaPaths'] != null) {
            final mediaPaths = widget.dataSrc?['mediaPaths'];
            if (mediaPaths is List && mediaPaths.isNotEmpty) {
              _shareImage(mediaPaths[0] ?? widget.dataSrc?['image']);
            } else if (widget.dataSrc?['image'] != null) {
              _shareImage(widget.dataSrc?['image']);
            }
          } else if (widget.dataSrc?['image'] != null) {
            _shareImage(widget.dataSrc?['image']);
          } else {}
        } else {}
      }).catchError((e) {
        debugPrint('Error initializing chat with friendId: $e');
        if (mounted && context.mounted) {
          _handleError('Failed to initialize chat. Please try again.',
              details: e.toString());
        }
      });
    } else {
      debugPrint('ChatScreen: No chatId and no friendId provided');
    }
  }

  void _shareImage(String imageUrl) {
    try {
      String message = '';
      if (widget.screen == 'share_recipe') {
        final title = widget.dataSrc?['title'] ?? '';
        final mealId = widget.dataSrc?['mealId'] ?? '';
        message =
            'Shared caption: ${capitalizeFirstLetter(title)} /$mealId /${capitalizeFirstLetter(title)} /${widget.screen ?? ''}';
      } else {
        // For non-recipe image shares, mark as private to prevent showing in posts
        final title = widget.dataSrc?['title'] ?? '';
        final id = widget.dataSrc?['id'] ?? '';
        final screen = widget.screen ?? 'post';
        message =
            'Shared caption: ${capitalizeFirstLetter(title)} /$id /${capitalizeFirstLetter(title)} /$screen /private';
      }

      if (chatId == null || chatId!.isEmpty) {
        debugPrint(
            '_shareImage ERROR: chatId is null or empty, cannot send message');
        return;
      }

      chatController.sendMessage(
        messageContent: message,
        imageUrls: [imageUrl],
        isPrivate: true, // Mark as private to prevent showing in posts
      );
    } catch (e, stackTrace) {
      debugPrint('Error sharing image: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted && context.mounted) {
        _handleError('Failed to share image. Please try again.',
            details: e.toString());
      }
    }
  }

  /// Check if a recipe with the given mealId was already shared in this chat
  bool _checkIfRecipeAlreadyShared(String mealId) {
    if (mealId.isEmpty) return false;

    // Check if any existing message contains this mealId
    final currentUserId = userService.userId ?? '';
    final sharePattern = '/$mealId /';

    for (final message in chatController.messages) {
      // Check if message is from current user and contains the mealId pattern
      if (message.senderId == currentUserId &&
          message.messageContent.contains(sharePattern) &&
          message.messageContent.contains('share_recipe')) {
        return true;
      }
    }

    return false;
  }

  void _shareRecipeWithoutImage() {
    try {
      if (widget.dataSrc == null) return;

      final mealId = widget.dataSrc?['mealId'] ?? '';
      final title = widget.dataSrc?['title'] ?? 'Recipe';

      String message =
          'Shared caption: ${capitalizeFirstLetter(title)} /$mealId /${capitalizeFirstLetter(title)} /${widget.screen ?? 'share_recipe'}';

      chatController.sendMessage(
        messageContent: message,
      );
    } catch (e) {
      debugPrint('Error sharing recipe without image: $e');
      if (mounted && context.mounted) {
        _handleError('Failed to share recipe. Please try again.',
            details: e.toString());
      }
    }
  }

  /// Handle errors with consistent snackbar display
  void _handleError(String message, {String? details}) {
    if (!mounted || !context.mounted) return;
    debugPrint('Error: $message${details != null ? ' - $details' : ''}');
    showTastySnackbar(
      'Error',
      message,
      context,
      backgroundColor: Colors.red,
    );
  }

  Future<void> _handleCalendarShare(Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String;

      String date;
      String message;
      String? calendarId;
      if (type == 'entire_calendar') {
        message = 'I\'d like to share my entire meal calendar with you.';
        date = DateFormat('MMM d, yyyy').format(DateTime.now());
        calendarId = data['calendarId'] as String?;
      } else {
        date = data['date'] as String? ?? 'No date specified';
        message = 'I\'d like to share my meal plan for $date with you.';
        calendarId = data['calendarId'] as String?;
      }

      await chatController.sendMessage(
        messageContent: message,
        shareRequest: {
          'type': type,
          'date': date,
          'name': userService.currentUser.value?.displayName,
          'friendName': widget.friend?.displayName,
          'calendarId': calendarId ?? 'No calendar ID',
          'header': data['header'] as String?,
        },
      );

      // Increment share count for non-premium users (handled by service)
      await chatController.incrementCalendarShareCount();
    } catch (e) {
      debugPrint('Error handling calendar share: $e');
      _handleError('Failed to send calendar share request. Please try again.',
          details: e.toString());
    }
  }

  // Helper method to get only the date part (without time) for comparison
  String _getDateOnly(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  // Helper method to build date header widget
  Widget _buildDateHeader(DateTime date, bool isDarkMode, TextTheme textTheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      // Format as "June 24, 2025" for older dates
      dateText = DateFormat('MMMM d, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.3)
                : kLightGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: textTheme.bodyMedium?.copyWith(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    // Check if latest message is a pending friend request
    bool isPendingFriendRequest = false;
    if (chatController.messages.isNotEmpty) {
      final lastMsg = chatController.messages.last;
      if (lastMsg.friendRequest != null &&
          (lastMsg.friendRequest?['status'] ?? 'pending') == 'pending') {
        isPendingFriendRequest = true;
      }
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Text(
          widget.friend?.displayName ?? 'Chat',
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          GestureDetector(
            onTap: widget.friendId!.isEmpty
                ? () {}
                : () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UserProfileScreen(userId: widget.friendId!),
                      ),
                    );
                  },
            child: Padding(
              padding: EdgeInsets.only(
                right: getPercentageWidth(2, context),
              ),
              child: CircleAvatar(
                backgroundImage: widget.friend?.profileImage != null &&
                        widget.friend!.profileImage!.isNotEmpty &&
                        widget.friend!.profileImage!.contains('http')
                    ? NetworkImage(widget.friend!.profileImage!)
                    : AssetImage(intPlaceholderImage) as ImageProvider,
                radius: getResponsiveBoxSize(context, 15, 15),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode
                  ? 'assets/images/background/imagedark.jpeg'
                  : 'assets/images/background/imagelight.jpeg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.5),
              isDarkMode ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: chatId == null
            ? noItemTastyWidget(
                "No chat yet...",
                "",
                context,
                false,
                '',
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: Column(
                  children: [
                    Expanded(
                      child: Obx(() {
                        final messages = chatController.messages;

                        if (messages.isEmpty) {
                          return const Center(
                            child: Text("No messages yet."),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                                _scrollController.position.maxScrollExtent);
                          }
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          itemCount: messages.length,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemBuilder: (context, index) {
                            final message = messages[index];

                            // Check if we need to show a date header
                            bool showDateHeader = false;
                            if (index == 0) {
                              // Always show date header for first message
                              showDateHeader = true;
                            } else {
                              // Check if date is different from previous message
                              final previousMessage = messages[index - 1];
                              final currentDate =
                                  _getDateOnly(message.timestamp.toDate());
                              final previousDate = _getDateOnly(
                                  previousMessage.timestamp.toDate());
                              showDateHeader = currentDate != previousDate;
                            }

                            return Column(
                              children: [
                                if (showDateHeader)
                                  _buildDateHeader(message.timestamp.toDate(),
                                      isDarkMode, textTheme),
                                ChatItem(
                                  dataSrc: message,
                                  isMe: message.senderId == userService.userId,
                                  chatController: chatController,
                                  chatId: chatId!,
                                ),
                              ],
                            );
                          },
                        );
                      }),
                    ),
                    _buildInputSection(isDarkMode, textTheme,
                        isDisabled: isPendingFriendRequest,
                        hint: isPendingFriendRequest
                            ? 'You can\'t send messages yet'
                            : 'Type your caption...'),
                    SizedBox(height: getPercentageHeight(3, context)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInputSection(bool isDarkMode, TextTheme textTheme,
      {bool isDisabled = false, String hint = 'Type your caption...'}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          getPercentageWidth(2, context),
          getPercentageHeight(0.8, context),
          getPercentageWidth(2, context),
          getPercentageHeight(2.8, context)),
      child: Row(
        children: [
          InkWell(
            onTap: isDisabled
                ? null
                : () async {
                    try {
                      final ImagePicker picker = ImagePicker();
                      // Pick at full quality, we'll compress properly in handleImageSend
                      List<XFile> pickedImages = await picker.pickMultiImage(
                        imageQuality: 100, // Full quality to avoid color shifts
                      );

                      if (pickedImages.isNotEmpty) {
                        // Convert XFile to File and call handleImageSend
                        List<File> imageFiles = pickedImages
                            .map((xfile) => File(xfile.path))
                            .toList();
                        await handleImageSend(
                          imageFiles,
                          null, // No caption for chat images
                          chatId!,
                          _scrollController,
                          chatController,
                        );
                      }
                    } catch (e) {
                      debugPrint('Error picking images: $e');
                      if (mounted) {
                        showTastySnackbar(
                          'Error',
                          'Failed to pick images. Please try again.',
                          context,
                          backgroundColor: kRed,
                        );
                      }
                    }
                  },
            child: const IconCircleButton(
              icon: Icons.camera_alt,
              size: kIconSizeMedium,
            ),
          ),
          SizedBox(width: getPercentageWidth(1, context)),
          Expanded(
            child: SafeTextFormField(
              controller: textController,
              keyboardType: TextInputType.multiline,
              enabled: !isDisabled,
              style: textTheme.bodyMedium?.copyWith(),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDarkMode ? kLightGrey : kWhite,
                enabledBorder: outlineInputBorder(20),
                focusedBorder: outlineInputBorder(20),
                border: outlineInputBorder(20),
                contentPadding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(1.2, context),
                    horizontal: getPercentageWidth(1.6, context)),
                hintText: hint,
                hintStyle: textTheme.bodyMedium?.copyWith(),
              ),
            ),
          ),
          SizedBox(width: getPercentageWidth(1, context)),
          InkWell(
            onTap: isDisabled
                ? null
                : () async {
                    try {
                      final messageText = textController.text.trim();
                      if (messageText.isNotEmpty && chatId != null) {
                        await chatController.sendMessage(
                            messageContent: messageText);
                        if (mounted) {
                          textController.clear();
                        }
                      }
                    } catch (e) {
                      debugPrint('Error sending message: $e');
                      if (mounted && context.mounted) {
                        _handleError(
                            'Failed to send message. Please try again.',
                            details: e.toString());
                      }
                    }
                  },
            child: const IconCircleButton(
              icon: Icons.send,
              size: kIconSizeMedium,
            ),
          ),
        ],
      ),
    );
  }
}
