import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tasteturner/data_models/meal_model.dart';
import '../constants.dart';
import '../data_models/post_model.dart';
import '../data_models/user_data_model.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/photo_manager.dart';
import '../pages/safe_text_field.dart';
import '../service/chat_controller.dart';

import '../widgets/icon_widget.dart';
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
      chatController.chatId = chatId!;
      chatController.listenToMessages();
      chatController.markMessagesAsRead(chatId!, widget.friendId!);

      if (widget.dataSrc != null && widget.dataSrc!.isNotEmpty) {
        if (widget.dataSrc?['screen'] == 'meal_design') {
          _handleCalendarShare(widget.dataSrc!);
        } else if (widget.dataSrc?['mediaPaths'] != null) {
          _shareImage(widget.dataSrc?['mediaPaths'][0]);
        }
      }
    } else if (widget.friendId != null) {
      chatController.initializeChat(widget.friendId!).then((_) {
        setState(() {
          chatId = chatController.chatId;
        });
        chatController.markMessagesAsRead(chatId!, widget.friendId!);

        if (widget.dataSrc != null && widget.dataSrc!.isNotEmpty) {
          if (widget.dataSrc?['screen'] == 'meal_design') {
            _handleCalendarShare(widget.dataSrc!);
          } else if (widget.dataSrc?['mediaPaths'] != null) {
            _shareImage(
                widget.dataSrc?['mediaPaths'][0] ?? widget.dataSrc?['image']);
          }
        }
      });
    }
  }

  void _shareImage(String imageUrl) {
    String message = '';
    if (widget.screen == 'battle_post') {
      message =
          'Shared from ${capitalizeFirstLetter(widget.dataSrc?['name'])} for ${capitalizeFirstLetter(widget.dataSrc?['category'])} Battle /${widget.dataSrc?['id']} /${widget.dataSrc?['name']} /${widget.screen}';
    } else if (widget.screen == 'share_recipe') {
      message =
          'Shared caption: ${capitalizeFirstLetter(widget.dataSrc?['title'])} /${widget.dataSrc?['mealId']} /${widget.dataSrc?['title']} /${widget.screen}';
    } else {
      message =
          'Shared caption: ${capitalizeFirstLetter(widget.dataSrc?['title'])} /${widget.dataSrc?['id']} /${widget.dataSrc?['title']} /${widget.screen}';
    }

    chatController.sendMessage(
      messageContent: message,
      imageUrls: [imageUrl],
    );
  }

  Future<void> _handleCalendarShare(Map<String, dynamic> data) async {
    final type = data['type'] as String;
    print('type: ${userService.userId}');

    String date;
    String message;
    String? calendarId;
    if (type == 'entire_calendar') {
      message = 'I\'d like to share my entire meal calendar with you.';
      date = DateFormat('MMM d, yyyy').format(DateTime.now());
      calendarId = data['calendarId'] as String?;
    } else {
      print('data: $data');
      date = data['date'] as String? ?? 'No date specified';
      message = 'I\'d like to share my meal plan for $date with you.';
      calendarId = data['calendarId'] as String?;
      print('calendarId: $calendarId');
    }

    await chatController.sendMessage(
      messageContent: message,
      shareRequest: {
        'type': type,
        'date': date,
        'name': userService.currentUser?.displayName,
        'friendName': widget.friend?.displayName,
        'calendarId': calendarId ?? 'No calendar ID',
        'header': data['header'] as String?,
      },
    );
    // If allowed, increment share count for non-premium users
    if (!(userService.currentUser?.isPremium ?? false)) {
      await firestore.collection('users').doc(userService.userId).set(
        {
          'calendarShares': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onNewMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
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
        leadingWidth: MediaQuery.of(context).size.width,
        leading: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: IconCircleButton(
                  isRemoveContainer: true,
                ),
              ),
            ),
            const Spacer(),
            Text(
              widget.friend?.displayName ?? 'Chat',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: isDarkMode ? kWhite : kDarkGrey),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 10),
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
              child: CircleAvatar(
                backgroundColor: kAccent,
                radius: 23,
                child: CircleAvatar(
                  backgroundImage: widget.friend?.profileImage != null &&
                          widget.friend!.profileImage!.isNotEmpty &&
                          widget.friend!.profileImage!.contains('http')
                      ? NetworkImage(widget.friend!.profileImage!)
                      : const AssetImage(intPlaceholderImage) as ImageProvider,
                  radius: 20,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
      body: chatId == null
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
                          return ChatItem(
                            dataSrc: message,
                            isMe: message.senderId == userService.userId,
                            chatController: chatController,
                            chatId: chatId!,
                          );
                        },
                      );
                    }),
                  ),
                  _buildInputSection(isDarkMode,
                      isDisabled: isPendingFriendRequest,
                      hint: isPendingFriendRequest
                          ? 'Waiting to accept'
                          : 'Type your caption...'),
                ],
              ),
            ),
    );
  }

  Future<void> _handleImageSend(List<File> images, String? caption) async {
    List<String> uploadedUrls = [];

    for (File image in images) {
      try {
        final String fileName =
            'chats/\\$chatId/\\${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = firebaseStorage.ref().child(fileName);

        final uploadTask = storageRef.putFile(image);
        final snapshot = await uploadTask;
        final imageUrl = await snapshot.ref.getDownloadURL();

        uploadedUrls.add(imageUrl);
      } catch (e, stack) {
        print('Error uploading image: \\${e}');
        print(stack);
      }
    }

    final postRef = firestore.collection('posts').doc();
    final postId = postRef.id;
    final messageContent =
        'Shared caption: ${capitalizeFirstLetter(caption ?? '')} /${postId} /${'post'} /${'private'}';

    final post = Post(
      id: postId,
      userId: userService.userId ?? '',
      mediaPaths: uploadedUrls,
      name: userService.currentUser?.displayName ?? '',
      category: 'general',
      isBattle: false,
      battleId: 'private',
      createdAt: DateTime.now(),
    );

    WriteBatch batch = firestore.batch();
    batch.set(postRef, post.toFirestore());
    batch.update(firestore.collection('users').doc(userService.userId), {
      'posts': FieldValue.arrayUnion([postRef.id]),
    });
    await batch.commit();

    // Send text + images together as a single message or separate depending on your logic
    await chatController.sendMessage(
      messageContent: messageContent,
      imageUrls: uploadedUrls,
      isPrivate: true,
    );
    _onNewMessage();
  }

  Widget _buildInputSection(bool isDarkMode,
      {bool isDisabled = false, String hint = 'Type your caption...'}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Row(
        children: [
          InkWell(
            onTap: isDisabled
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) {
                        return CustomImagePickerModal(
                          onSend: _handleImageSend,
                        );
                      },
                    );
                  },
            child: const IconCircleButton(
              icon: Icons.camera_alt,
              h: 35,
              w: 35,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SafeTextFormField(
              controller: textController,
              keyboardType: TextInputType.multiline,
              enabled: !isDisabled,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? kWhite : kBlack,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDarkMode ? kLightGrey : kWhite,
                enabledBorder: outlineInputBorder(20),
                focusedBorder: outlineInputBorder(20),
                border: outlineInputBorder(20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDarkMode
                      ? kWhite.withOpacity(0.5)
                      : kBlack.withOpacity(0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: isDisabled
                ? null
                : () async {
                    final messageText = textController.text.trim();
                    if (messageText.isNotEmpty && chatId != null) {
                      await chatController.sendMessage(
                          messageContent: messageText);
                      textController.clear();
                    }
                  },
            child: const IconCircleButton(
              icon: Icons.send,
              h: 40,
              w: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatItem extends StatelessWidget {
  final ChatScreenData dataSrc;
  final bool isMe;
  final ChatController chatController;
  final String chatId;

  const ChatItem({
    super.key,
    required this.dataSrc,
    required this.isMe,
    required this.chatController,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    double screenWidth = MediaQuery.of(context).size.width;
    List<String> extractedItems = extractSlashedItems(dataSrc.messageContent);
    if (extractedItems.isEmpty) {
      extractedItems.add(dataSrc.messageId);
      extractedItems.add('name');
      extractedItems.add('post');
    }
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: screenWidth * 0.7),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? kAccentLight.withOpacity(0.2)
                : (isDarkMode
                    ? Colors.white12
                    : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Display Images if any
              if (dataSrc.imageUrls.isNotEmpty)
                Column(
                  children: dataSrc.imageUrls.map((url) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          if (extractedItems.isNotEmpty &&
                              extractedItems.last == 'share_recipe') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(
                                  mealData:
                                      Meal.fromJson(extractedItems[0], {}),
                                  screen: extractedItems.last,
                                ),
                              ),
                            );
                          } else if (extractedItems.isNotEmpty &&
                              extractedItems.last == 'post') {
                            // Navigate to PostDetailScreen
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeDetailScreen(
                                  dataSrc: dataSrc.toMap(),
                                  screen: 'myPost',
                                ),
                              ),
                            );
                          } else {
                            // Navigate to ChallengeDetailScreen
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeDetailScreen(
                                  screen: extractedItems.isNotEmpty
                                      ? extractedItems.last
                                      : 'battle_post',
                                  dataSrc: dataSrc.toMap(),
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: url.contains('http')
                              ? Image.network(
                                  url,
                                  height: 150,
                                  width: screenWidth * 0.7,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    intPlaceholderImage,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  getAssetImageForItem(url),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Show Text if Available
              if (dataSrc.messageContent.isNotEmpty)
                Text(
                  getTextBeforeSlash(dataSrc.messageContent),
                  style: const TextStyle(fontSize: 12),
                ),

              // Show Calendar Share Request if available
              if (dataSrc.shareRequest != null)
                _buildShareRequest(context, isDarkMode),

              // Show Friend Request if available
              if (dataSrc.friendRequest != null)
                _buildFriendRequest(
                    context, isDarkMode, chatId, dataSrc.messageId),

              const SizedBox(height: 4),

              // Timestamp & Read Status
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(dataSrc.timestamp.toDate()),
                    style: const TextStyle(fontSize: 10),
                  ),
                  if (isMe) const SizedBox(width: 4),
                  if (isMe)
                    const Icon(
                      Icons.done_all,
                      size: 14,
                      color: Colors.blue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendRequest(
      BuildContext context, bool isDarkMode, String chatId, String messageId) {
    final friendRequest = dataSrc.friendRequest!;
    final status = friendRequest['status'] as String? ?? 'pending';
    final friendName = friendRequest['friendName'] as String? ?? 'Friend';
    final date = friendRequest['date'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kAccentLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined, size: 18, color: kAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$friendName wants to be your friend',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status == 'pending')
                TextButton(
                  onPressed: () async {
                    // Accept friend request logic
                    await ChatController.instance.acceptFriendRequest(
                      chatId,
                      messageId,
                    );
                  },
                  child: const Text('Accept'),
                  style: TextButton.styleFrom(
                      foregroundColor: isDarkMode ? kWhite : kDarkGrey),
                ),
              if (status == 'accepted')
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Text('Accepted', style: TextStyle(color: kAccent)),
                ),
            ],
          ),
          if (date != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Requested on $date',
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShareRequest(BuildContext context, bool isDarkMode) {
    final shareRequest = dataSrc.shareRequest!;
    final status = shareRequest['status'] as String;
    final type = shareRequest['type'] as String;
    final date = shareRequest['date'] as String?;
    String formattedDate = '';
    if (date != null && date.isNotEmpty) {
      // Try to parse as ISO, otherwise just display as is
      try {
        // If date is already in display format, just use it
        if (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(date)) {
          formattedDate =
              DateFormat('MMM d, yyyy').format(DateTime.parse(date));
        } else {
          formattedDate = date; // Already display format
        }
      } catch (e) {
        formattedDate = date; // Fallback to raw string
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type == 'entire_calendar' ? Icons.calendar_month : Icons.today,
              size: 16,
              color: kAccent,
            ),
            const SizedBox(width: 8),
            Text(
              type == 'entire_calendar' ? 'Calendar Share' : 'Day Share',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: kAccent,
              ),
            ),
          ],
        ),
        if (date != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Date: $formattedDate',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        if (!isMe && status == 'pending')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    try {
                      chatController.acceptCalendarShare(dataSrc.messageId);
                    } catch (e) {
                      print('Error accepting calendar share: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to accept calendar share. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: kAccent.withOpacity(0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(color: kAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (status == 'accepted')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Accepted',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
