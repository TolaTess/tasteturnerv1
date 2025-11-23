import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart' show debugPrint;

import '../constants.dart';
import '../data_models/post_model.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import 'post_service.dart';

class PostController extends GetxController {
  static PostController instance = Get.find();

  // Reactive list of posts
  var isLoading = true.obs;
  final RxList<Post> posts = <Post>[].obs;
  final RxList<Post> userPosts = <Post>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchPosts();
  }

  // Fetch posts using cloud function to avoid N+1 query problem
  void fetchPosts() async {
    isLoading.value = true;
    try {
      // Use PostService which calls cloud function with batched user data
      PostService postService;
      try {
        postService = PostService.instance;
      } catch (e) {
        // PostService not initialized, use fallback
        debugPrint('PostService not available, using fallback: $e');
        _fetchPostsFallback();
        return;
      }

      final result = await postService.getPostsFeed(
        category: 'general',
        limit: 50,
      );

      if (result.isSuccess && result.posts.isNotEmpty) {
        final fetchedPosts = result.posts.map((postData) {
          // Convert Map to Post object
          return Post(
            id: postData['id'] ?? '',
            mealId: postData['mealId'],
            userId: postData['userId'] ?? '',
            name: postData['username'] ?? postData['name'] ?? 'Unknown',
            avatar: postData['avatar'] ?? '',
            username: postData['username'] ?? postData['name'] ?? 'Unknown',
            isPremium: postData['isPremium'] ?? false,
            mediaPaths: List<String>.from(postData['mediaPaths'] ?? []),
            category: postData['category'] ?? 'general',
            favorites: List<String>.from(postData['favorites'] ?? []),
            createdAt: postData['createdAt'] != null
                ? (postData['createdAt'] is String
                    ? DateTime.tryParse(postData['createdAt'])
                    : postData['createdAt'] is DateTime
                        ? postData['createdAt']
                        : null)
                : null,
            isVideo: postData['isVideo'] ?? false,
          );
        }).toList();

        posts.assignAll(fetchedPosts);
        isLoading.value = false;
      } else {
        // If cloud function returns empty or error, use fallback
        _fetchPostsFallback();
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      // Fallback to direct Firestore query if cloud function fails
      _fetchPostsFallback();
    }
  }

  // Fallback method using direct Firestore query (with batched user fetching)
  void _fetchPostsFallback() async {
    try {
      final snapshot = await firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final fetchedPosts =
          snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      // Batch fetch user data to avoid N+1 queries
      final userIds = fetchedPosts
          .where((post) => post.userId.isNotEmpty)
          .map((post) => post.userId)
          .toSet()
          .toList();

      final userDataMap = <String, Map<String, dynamic>>{};

      // Fetch all user data in parallel
      if (userIds.isNotEmpty) {
        final userPromises = userIds.map((userId) async {
          try {
            final userDoc =
                await firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              userDataMap[userId] = userDoc.data()!;
            }
          } catch (e) {
            debugPrint('Error fetching user $userId: $e');
          }
        });

        await Future.wait(userPromises);
      }

      // Attach user data to posts
      for (var post in fetchedPosts) {
        if (post.userId.isNotEmpty && userDataMap.containsKey(post.userId)) {
          final userData = userDataMap[post.userId]!;
          post.avatar = userData['profileImage'] ?? '';
          post.username = userData['displayName'] ?? 'Unknown';
          post.isPremium = userData['isPremium'] ?? false;
        }
      }

      posts.assignAll(fetchedPosts);
    } catch (e) {
      debugPrint('Error in fallback post fetch: $e');
      if (Get.context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', Get.context!,
            backgroundColor: kRed);
      }
    }
  }

  Future<List<Post>> getPostsByIds(List<String> postIds) async {
    final List<Post> allPosts = [];

    // Process postIds in chunks of 30 to comply with Firestore limitations
    for (var i = 0; i < postIds.length; i += 30) {
      final end = (i + 30 < postIds.length) ? i + 30 : postIds.length;
      final chunk = postIds.sublist(i, end);

      final snapshots = await FirebaseFirestore.instance
          .collection('posts')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      allPosts.addAll(snapshots.docs.map((doc) => Post.fromFirestore(doc)));
    }

    return allPosts;
  }

  Future<List<Post>> getUserPosts(String userId) async {
    try {
      // Fetch the user's document from Firestore
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        // Handle the case where the user document does not exist
        return [];
      }

      // Safely access the 'posts' field and convert it to a list of strings
      final List<String> postIds =
          (userDoc.data()?['posts'] as List<dynamic>? ?? [])
              .map((postId) => postId.toString())
              .toList();

      // Fetch and return posts by their IDs
      return postIds.isNotEmpty ? await getPostsByIds(postIds) : [];
    } catch (e) {
      // Log any errors during the process
      return [];
    }
  }

  bool isFileSizeValid(String filePath, int maxSizeInMB) {
    final file = File(filePath);
    final fileSizeInBytes = file.lengthSync();
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024; // Convert MB to bytes
    return fileSizeInBytes <= maxSizeInBytes;
  }

  Future<String> _compressAndResizeImage(String imagePath) async {
    final File imageFile = File(imagePath);
    final bool isLargeFile = await imageFile.length() > 5 * 1024 * 1024; // 5MB

    // First pass: Decode and analyze the image
    final List<int> bytes = await imageFile.readAsBytes();
    final Uint8List uint8Bytes = Uint8List.fromList(bytes);
    final img.Image? originalImage = img.decodeImage(uint8Bytes);

    if (originalImage == null) throw Exception('Failed to decode image');

    // Calculate optimal dimensions based on the device
    final (int targetWidth, int targetHeight) =
        await _calculateOptimalDimensions(
      originalImage.width,
      originalImage.height,
    );

    // First compression pass using flutter_image_compress for better quality
    final String firstPassPath = await _performFirstCompressionPass(
      imagePath,
      targetWidth,
      targetHeight,
      isLargeFile,
    );

    // Check if the first pass achieved desired file size
    final File firstPassFile = File(firstPassPath);
    final bool needsSecondPass =
        await firstPassFile.length() > 1 * 1024 * 1024; // 1MB

    if (needsSecondPass) {
      return await _performSecondCompressionPass(
        firstPassPath,
        targetWidth,
        targetHeight,
      );
    }

    return firstPassPath;
  }

  Future<(int, int)> _calculateOptimalDimensions(
      int originalWidth, int originalHeight) async {
    const int maxDimension = 1200;
    final double aspectRatio = originalWidth / originalHeight;

    // Check if we're on iOS for device-specific optimizations
    if (Platform.isIOS) {
      final deviceInfo = await DeviceInfoPlugin().iosInfo;
      final bool isModernDevice =
          int.parse(deviceInfo.systemVersion.split('.')[0]) >= 13;

      // Modern iOS devices can handle larger images better
      if (isModernDevice) {
        const int iosMaxDimension = 1600;
        if (aspectRatio > 1) {
          return (iosMaxDimension, (iosMaxDimension / aspectRatio).round());
        } else {
          return ((iosMaxDimension * aspectRatio).round(), iosMaxDimension);
        }
      }
    }

    // Default dimensions for other devices
    if (aspectRatio > 1) {
      return (maxDimension, (maxDimension / aspectRatio).round());
    } else {
      return ((maxDimension * aspectRatio).round(), maxDimension);
    }
  }

  Future<String> _performFirstCompressionPass(
    String imagePath,
    int targetWidth,
    int targetHeight,
    bool isLargeFile,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final String outputPath =
        '${tempDir.path}/compressed_1st_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await FlutterImageCompress.compressAndGetFile(
      imagePath,
      outputPath,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: isLargeFile ? 80 : 90,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );

    return outputPath;
  }

  Future<String> _performSecondCompressionPass(
    String inputPath,
    int targetWidth,
    int targetHeight,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final String outputPath =
        '${tempDir.path}/compressed_2nd_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await FlutterImageCompress.compressAndGetFile(
      inputPath,
      outputPath,
      minWidth: (targetWidth * 0.8).round(), // Reduce dimensions by 20%
      minHeight: (targetHeight * 0.8).round(),
      quality: 70,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    // Clean up first pass file
    await File(inputPath).delete();
    return outputPath;
  }

  // Helper method to ensure usersPosts document exists
  Future<void> _ensureUsersPostsDocumentExists(String userId) async {
    try {
      final usersPostsDoc = firestore.collection('usersPosts').doc(userId);
      final usersPostsSnapshot = await usersPostsDoc.get();

      if (!usersPostsSnapshot.exists) {
        await usersPostsDoc.set({
          'posts': [],
          'userId': userId,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {}
    } catch (e) {
      throw Exception('Failed to ensure usersPosts document exists: $e');
    }
  }

  Future<void> uploadPost(
      Post post, String userId, List<String> imagePaths) async {
    try {
      final postRef = firestore.collection('posts').doc();
      List<String> downloadUrls = [];

      for (String imagePath in imagePaths) {
        if (imagePath.startsWith('http')) {
          downloadUrls.add(imagePath);
          continue;
        }

        if (!File(imagePath).existsSync()) {
          continue;
        }

        // Validate file size before processing
        if (!isFileSizeValid(imagePath, 20)) {
          // 20MB max input size
          continue;
        }

        final String compressedPath = await _compressAndResizeImage(imagePath);
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
        final storageRef = firebaseStorage.ref().child('post_images/$fileName');

        try {
          final uploadTask = storageRef.putFile(File(compressedPath));
          final snapshot = await uploadTask.whenComplete(() => null);
          final downloadUrl = await snapshot.ref.getDownloadURL();
          downloadUrls.add(downloadUrl);
        } finally {
          // Ensure cleanup of temporary files
          try {
            await File(compressedPath).delete();
          } catch (e) {
            debugPrint('Error deleting temporary compressed file: $e');
          }
        }
      }

      if (downloadUrls.isEmpty) {
        throw Exception('No valid images to upload');
      }

      final updatedPost = post.copyWith(
        id: post.id.isEmpty
            ? postRef.id
            : post.id, // Use generated ID if post.id is empty
        mediaPaths: downloadUrls,
        createdAt: post.createdAt ?? DateTime.now(),
      );

      // Ensure usersPosts document exists before updating
      await _ensureUsersPostsDocumentExists(userId);

      WriteBatch batch = firestore.batch();
      batch.set(postRef, updatedPost.toFirestore());

      // Now we can safely update the usersPosts document
      batch.update(firestore.collection('usersPosts').doc(userId), {
        'posts': FieldValue.arrayUnion([postRef.id]),
      });

      try {
        await batch.commit();
        debugPrint('Successfully uploaded post and updated user references');
      } catch (batchError) {
        debugPrint('Batch commit failed: $batchError');
        // Provide more specific error message
        if (batchError.toString().contains('permission')) {
          throw Exception(
              'Permission denied. Please check your account status.');
        } else if (batchError.toString().contains('network') ||
            batchError.toString().contains('unavailable')) {
          throw Exception(
              'Network error. Please check your connection and try again.');
        } else {
          throw Exception('Failed to save post. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('Error in uploadPost: $e');
      // Re-throw with more context if it's not already a formatted exception
      if (e is Exception &&
          !e.toString().contains('Permission') &&
          !e.toString().contains('Network') &&
          !e.toString().contains('Failed to save')) {
        throw Exception('Failed to upload post: $e');
      }
      rethrow;
    }
  }

  Future<void> deletePostAndImages(String postId, String userId) async {
    try {
      final postRef = firestore.collection('posts').doc(postId);
      final postSnapshot = await postRef.get();

      if (!postSnapshot.exists) {
        return;
      }

      final postData = postSnapshot.data() as Map<String, dynamic>;
      final List<String> mediaPaths =
          List<String>.from(postData['mediaPaths'] ?? []);

      // Use utility to delete images
      await deleteImagesFromStorage(mediaPaths);

      // Remove post ID from user's posts array
      final usersPostsDoc = firestore.collection('usersPosts').doc(userId);
      final usersPostsSnapshot = await usersPostsDoc.get();

      if (usersPostsSnapshot.exists) {
        await usersPostsDoc.update({
          'posts': FieldValue.arrayRemove([postId]),
        });
      } else {}

      // Delete the post document
      await postRef.delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAnyPost({
    required String postId,
    required String userId,
  }) async {
    // Remove the post and its images from posts collection and user
    await deletePostAndImages(postId, userId);
  }

  /// Update an existing post with new fields (e.g., mealId after analysis)
  Future<void> updatePost({
    required String postId,
    Map<String, dynamic>? updateData,
  }) async {
    try {
      if (updateData == null || updateData.isEmpty) {
        return;
      }

      final postRef = firestore.collection('posts').doc(postId);
      final postSnapshot = await postRef.get();

      if (!postSnapshot.exists) {
        return;
      }

      // Update the post document with provided fields
      await postRef.update(updateData);
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }
}
