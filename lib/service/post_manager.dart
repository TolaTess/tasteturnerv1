import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
          print('File does not exist at path: $imagePath');
          continue;
        }

        // Validate file size before processing
        if (!isFileSizeValid(imagePath, 20)) {
          // 20MB max input size
          print('File too large: $imagePath');
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
          await File(compressedPath)
              .delete()
              .catchError((e) => print('Error cleaning up: $e'));
        }
      }

      if (downloadUrls.isEmpty) {
        throw Exception('No valid images to upload');
      }

      final updatedPost = post.copyWith(mediaPaths: downloadUrls);
      WriteBatch batch = firestore.batch();
      batch.set(postRef, updatedPost.toFirestore());
      batch.update(firestore.collection('users').doc(userId), {
        'posts': FieldValue.arrayUnion([postRef.id]),
      });
      await batch.commit();
    } catch (e) {
      print('Error uploading post: $e');
      throw Exception('Failed to upload post: $e');
    }
  }
}
