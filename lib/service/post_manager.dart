import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../data_models/post_model.dart';

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

  // Fetch posts and listen for real-time updates
  void fetchPosts() async {
    firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      final fetchedPosts =
          snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      // Fetch avatar for each post from user collection
      for (var post in fetchedPosts) {
        if (post.userId != null && post.userId!.isNotEmpty) {
          try {
            final userDoc =
                await firestore.collection('users').doc(post.userId).get();
            if (userDoc.exists) {
              post.avatar = userDoc.data()?['profileImage'] ?? '';
              post.username = userDoc.data()?['displayName'] ?? '';
              post.isPremium = userDoc.data()?['isPremium'] ?? false;
            }
          } catch (e) {
            print('Error fetching user avatar: $e');
          }
        }
      }

      posts.assignAll(fetchedPosts); // Update the reactive list
    });
  }

  Future<List<Post>> getPostsByIds(List<String> postIds) async {
    final snapshots = await FirebaseFirestore.instance
        .collection('posts')
        .where(FieldPath.documentId, whereIn: postIds)
        .get();

    return snapshots.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  Future<List<Post>> getUserPosts(String userId) async {
    try {
      // Fetch the user's document from Firestore
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        // Handle the case where the user document does not exist
        print('User document not found.');
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
      print('Error fetching user posts: $e');
      return [];
    }
  }

  bool isFileSizeValid(String filePath, int maxSizeInMB) {
    final file = File(filePath);
    final fileSizeInBytes = file.lengthSync();
    final maxSizeInBytes = 20 * 1024; // 20kb in bytes
    return fileSizeInBytes <= maxSizeInBytes;
  }

  Future<String> _compressAndResizeImage(String imagePath) async {
    // Read the image file
    final File imageFile = File(imagePath);
    final List<int> bytes = await imageFile.readAsBytes();
    final Uint8List uint8Bytes = Uint8List.fromList(bytes);
    final img.Image? image = img.decodeImage(uint8Bytes);

    if (image == null) throw Exception('Failed to decode image');

    // Calculate new dimensions while maintaining aspect ratio
    const int maxDimension = 1200; // Maximum dimension for posts
    final double aspectRatio = image.width / image.height;
    int newWidth = image.width;
    int newHeight = image.height;

    if (image.width > maxDimension || image.height > maxDimension) {
      if (aspectRatio > 1) {
        newWidth = maxDimension;
        newHeight = (maxDimension / aspectRatio).round();
      } else {
        newHeight = maxDimension;
        newWidth = (maxDimension * aspectRatio).round();
      }
    }

    // Resize the image
    final img.Image resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
    );

    // Compress the image
    final List<int> compressed = img.encodeJpg(resized, quality: 85);
    final Uint8List compressedBytes = Uint8List.fromList(compressed);

    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final String tempPath =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(tempPath).writeAsBytes(compressedBytes);

    return tempPath;
  }

  Future<void> uploadPost(
      Post post, String userId, List<String> imagePaths) async {
    try {
      // Create a reference for the new post document
      final postRef = firestore.collection('posts').doc();

      // Upload images to Firebase Storage
      List<String> downloadUrls = [];
      for (String imagePath in imagePaths) {
        // Check if the path is already a URL
        if (imagePath.startsWith('http')) {
          downloadUrls.add(imagePath);
          continue;
        }

        // Handle local file
        if (!File(imagePath).existsSync()) {
          print('File does not exist at path: $imagePath');
          continue;
        }

        // Compress and resize image before upload
        final String compressedPath = await _compressAndResizeImage(imagePath);

        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
        final storageRef = firebaseStorage.ref().child('post_images/$fileName');

        final uploadTask = storageRef.putFile(File(compressedPath));
        final snapshot = await uploadTask.whenComplete(() => null);
        final downloadUrl = await snapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);

        // Clean up temporary file
        await File(compressedPath).delete();
      }

      if (downloadUrls.isEmpty) {
        throw Exception('No valid images to upload');
      }

      // Create a new Post object with the download URLs
      final updatedPost = post.copyWith(mediaPaths: downloadUrls);

      // Start a batch operation
      WriteBatch batch = firestore.batch();

      // Add the post to the 'posts' collection
      batch.set(postRef, updatedPost.toFirestore());

      // Add the post ID to the user's 'posts' field
      final userRef = firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'posts': FieldValue.arrayUnion([postRef.id]),
      });

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error uploading post: $e');
      throw Exception('Failed to upload post: $e');
    }
  }
}
