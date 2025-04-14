import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/icon_widget.dart';
import 'safe_text_field.dart';

class CommentSection extends StatefulWidget {
  final String postId;
  const CommentSection({super.key, required this.postId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  /// ✅ Fetch comments from Firestore
  Future<void> _fetchComments() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      comments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'],
          'content': data['content'],
          'avatar': data['avatar'],
          'likes': List<String>.from(data['likes'] ?? []),
          'timestamp': data['timestamp'],
        };
      }).toList();
    });
  }

  /// ✅ Add a new comment
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc();

    await commentRef.set({
      'userId': userService.userId,
      'content': _commentController.text,
      'avatar': userService.currentUser!.profileImage,
      'likes': [],
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      comments.insert(0, {
        'id': commentRef.id,
        'userId': userService.userId,
        'content': _commentController.text,
        'avatar': userService.currentUser!.profileImage,
        'likes': [],
        'timestamp': Timestamp.now(),
      });
    });

    _commentController.clear();

    // ✅ Increment total comment count in Firestore
    FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
      'numComments': FieldValue.increment(1),
    });
  }

  Future<void> _toggleCommentLike(String commentId, List<String> likes) async {
    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    bool isLiked = likes.contains(userService.userId);
    List<String> updatedLikes = List.from(likes);

    setState(() {
      if (isLiked) {
        updatedLikes.remove(userService.userId);
      } else {
        updatedLikes.add(userService.userId ?? '');
      }
    });

    await commentRef.update({'likes': updatedLikes});

    setState(() {
      // Update the specific comment's likes inside the comments list
      int index = comments.indexWhere((c) => c['id'] == commentId);
      if (index != -1) {
        comments[index]['likes'] = updatedLikes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        color: isDarkMode ? kDarkGrey : kBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title
            const Text(
              "Comments",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Comments List
            Expanded(
              child: comments.isEmpty
                  ? const Center(child: Text("No comments yet"))
                  : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (comment['avatar'] != null &&
                                    comment['avatar'].isNotEmpty &&
                                    comment['avatar'].contains('http'))
                                ? NetworkImage(comment['avatar'])
                                : const AssetImage(intPlaceholderImage)
                                    as ImageProvider,
                            radius: 24,
                          ),
                          title: Text(
                            comment['content'],
                            style: TextStyle(
                                color:
                                    isDarkMode ? kWhite : kBlack),
                          ),
                          subtitle: Text(
                            timeAgo(comment['timestamp']),
                            style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? kLightGrey
                                    : kDarkGrey),
                          ),
                          trailing: GestureDetector(
                            onTap: () => _toggleCommentLike(
                              comment['id'],
                              List<String>.from(comment['likes'] ?? []),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  comment['likes'].contains(userService.userId)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: comment['likes']
                                          .contains(userService.userId)
                                      ? Colors.red
                                      : isDarkMode
                                          ? kBackgroundColor.withValues(alpha: kMidOpacity)
                                          : kLightGrey.withValues(alpha: kOpacity),
                                ),
                                const SizedBox(width: 5),
                                if (comment['likes'].isNotEmpty)
                                  Text(
                                    "${comment['likes'].length}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? kLightGrey
                                          : kDarkGrey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Add Comment Input
            SafeTextField(
              controller: _commentController,
              style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey),
              decoration: InputDecoration(
                hintText: "Write a comment...",
                hintStyle: TextStyle(
                    color: isDarkMode ? kWhite : kDarkGrey),
                enabledBorder: outlineInputBorder(20),
                focusedBorder: outlineInputBorder(20),
                border: outlineInputBorder(20),
                suffixIcon: IconButton(
                  icon: const IconCircleButton(
                    icon: Icons.send,
                    isRemoveContainer: true,
                  ),
                  onPressed: _addComment,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
