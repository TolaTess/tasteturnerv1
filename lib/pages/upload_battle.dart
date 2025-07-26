import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../constants.dart';
import '../data_models/post_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../screens/food_analysis_results_screen.dart';
import '../widgets/bottom_nav.dart';
import '../service/battle_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/primary_button.dart';
import '../widgets/video_player_widget.dart';

class UploadBattleImageScreen extends StatefulWidget {
  final String battleId;
  final String battleCategory;
  final bool isMainPost;

  const UploadBattleImageScreen({
    super.key,
    required this.battleId,
    this.battleCategory = 'Main',
    this.isMainPost = false,
  });

  @override
  State<UploadBattleImageScreen> createState() =>
      _UploadBattleImageScreenState();
}

class _UploadBattleImageScreenState extends State<UploadBattleImageScreen> {
  bool isUploading = false;
  List<XFile> _selectedMedia = [];
  String selectedCategoryId = '';
  String selectedCategory = 'general';
  bool _isVideo = false;
  double _uploadProgress = 0.0;
  String? _videoThumbnailPath;

  Future<String> _compressAndResizeBattleImage(String imagePath) async {
    // Read the image file
    final File imageFile = File(imagePath);
    final List<int> bytes = await imageFile.readAsBytes();
    final Uint8List uint8Bytes = Uint8List.fromList(bytes);
    final img.Image? image = img.decodeImage(uint8Bytes);

    if (image == null) throw Exception('Failed to decode image');

    // Calculate new dimensions while maintaining aspect ratio
    const int maxDimension = 512; // Maximum dimension for battle images
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
        '${tempDir.path}/battle_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(tempPath).writeAsBytes(compressedBytes);

    return tempPath;
  }

  /// Validate and optimize video file size for better loading performance
  Future<String> _optimizeVideo(String videoPath) async {
    final File videoFile = File(videoPath);
    final int originalSize = await videoFile.length();

    print(
        'Original video size: ${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB');

    // Set reasonable file size limits for battle videos (8 seconds max)
    const int maxSizeBytes = 15 * 1024 * 1024; // 15MB limit for 8-second videos
    const int warningSize = 8 * 1024 * 1024; // 8MB warning threshold

    if (originalSize > maxSizeBytes) {
      throw Exception(
          'Video file is too large (${(originalSize / (1024 * 1024)).toStringAsFixed(1)}MB). '
          'Maximum allowed is ${(maxSizeBytes / (1024 * 1024)).toStringAsFixed(0)}MB. '
          'Please record a shorter video or use lower quality settings.');
    }

    // Show warning for large files but allow upload
    if (originalSize > warningSize && mounted) {
      showTastySnackbar(
        'Large Video File',
        'Video is ${(originalSize / (1024 * 1024)).toStringAsFixed(1)}MB. This may take longer to load.',
        context,
        backgroundColor: Colors.orange,
      );
    }

    return videoPath; // Return original path since no compression is available
  }

  /// Generate thumbnail for video preview to avoid loading full video
  Future<String?> _generateVideoThumbnail(String videoPath) async {
    try {
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 400, // Reasonable size for preview
        quality: 80,
        timeMs: 1000, // Get thumbnail from 1 second mark
      );
      return thumbnailPath;
    } catch (e) {
      print('Failed to generate video thumbnail: $e');
      return null;
    }
  }

  Future<void> _pickMedia({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();

    final choice = await showMediaSelectionDialog(
        isCamera: fromCamera, context: context, isVideo: true);
    if (choice == null) return;

    if (fromCamera) {
      final XFile? media = choice == 'photo'
          ? await picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 80,
              maxWidth: 1024, // Limit resolution for faster processing
              maxHeight: 1024,
            )
          : await picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: Duration(seconds: 8),
            );

      if (media != null) {
        if (choice == 'photo') {
          XFile? cropped = await cropImage(
              media, context, getThemeProvider(context).isDarkMode);
          if (cropped != null) {
            setState(() {
              _selectedMedia = [cropped];
              _isVideo = false;
              _videoThumbnailPath = null;
            });
          }
        } else {
          // Show compression progress for video
          _showVideoProcessingDialog();

          try {
            // Optimize video and generate thumbnail
            final String optimizedPath = await _optimizeVideo(media.path);
            final String? thumbnailPath =
                await _generateVideoThumbnail(optimizedPath);

            Navigator.pop(context); // Close processing dialog

            setState(() {
              _selectedMedia = [XFile(optimizedPath)];
              _isVideo = true;
              _videoThumbnailPath = thumbnailPath;
            });
          } catch (e) {
            Navigator.pop(context); // Close processing dialog
            if (mounted) {
              showTastySnackbar(
                'Video Processing Failed',
                e.toString(),
                context,
                backgroundColor: kRed,
              );
            }
          }
        }
      }
    } else {
      if (choice == 'photos') {
        List<XFile> pickedImages =
            await openMultiImagePickerModal(context: context);
        if (pickedImages.isNotEmpty) {
          List<XFile> croppedImages = [];
          for (final img in pickedImages) {
            final XFile? cropped = await cropImage(
                img, context, getThemeProvider(context).isDarkMode);
            if (cropped != null) {
              croppedImages.add(cropped);
            }
          }
          if (croppedImages.isNotEmpty) {
            setState(() {
              _selectedMedia = croppedImages;
              _isVideo = false;
              _videoThumbnailPath = null;
            });
          }
        }
      } else {
        final XFile? video =
            await picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          // Show compression progress for video
          _showVideoProcessingDialog();

          try {
            // Optimize video and generate thumbnail
            final String optimizedPath = await _optimizeVideo(video.path);
            final String? thumbnailPath =
                await _generateVideoThumbnail(optimizedPath);

            Navigator.pop(context); // Close processing dialog

            setState(() {
              _selectedMedia = [XFile(optimizedPath)];
              _isVideo = true;
              _videoThumbnailPath = thumbnailPath;
            });
          } catch (e) {
            Navigator.pop(context); // Close processing dialog
            if (mounted) {
              showTastySnackbar(
                'Video Processing Failed',
                e.toString(),
                context,
                backgroundColor: kRed,
              );
            }
          }
        }
      }
    }
  }

  void _showVideoProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor:
            getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: kAccent),
            SizedBox(height: getPercentageHeight(2, context)),
            Text(
              'Optimizing video for faster loading...',
              style: TextStyle(
                color: getThemeProvider(context).isDarkMode ? kWhite : kBlack,
                fontSize: getTextScale(3.5, context),
              ),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              'This may take a moment',
              style: TextStyle(
                color: getThemeProvider(context).isDarkMode
                    ? kWhite.withValues(alpha: 0.7)
                    : kBlack.withValues(alpha: 0.7),
                fontSize: getTextScale(3, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadMedia(String postId) async {
    if (_selectedMedia.isEmpty) {
      if (mounted) {
        _pickMedia(fromCamera: false);
      }
      return;
    }

    if (selectedCategoryId.isEmpty) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Please select a category first.',
          context,
        );
      }
      return;
    }

    setState(() {
      isUploading = true;
      _uploadProgress = 0.0;
    });

    print('Selected category: $selectedCategory');
    print('Selected category id: $selectedCategoryId');
    print('Is video: $_isVideo');
    print('Selected media: ${_selectedMedia.first.path}');
    print('Battle id: ${widget.battleId}');
    print('Battle category: ${widget.battleCategory}');
    print('Is main post: ${widget.isMainPost}');

    try {
      // If this is for analysis (postId is 'analyze_and_upload') and not a video, do analysis FIRST
      if (postId == 'analyze_and_upload' && !_isVideo) {
        // Show loading dialog for analysis
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor:
                  getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: kAccent),
                  SizedBox(height: getPercentageHeight(2, context)),
                  Text(
                    'Analyzing food image with AI...',
                    style: TextStyle(
                      color: getThemeProvider(context).isDarkMode
                          ? kWhite
                          : kBlack,
                      fontSize: getTextScale(3.5, context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Analyze the image with AI first
        final analysisResult = await geminiService.analyzeFoodImageWithContext(
          imageFile: File(_selectedMedia.first.path),
          mealType: getMealTimeOfDay(),
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
        }

        // Navigate to food analysis results screen for NEW analyze & upload flow
        if (mounted) {
          setState(() => isUploading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodAnalysisResultsScreen(
                imageFile: File(_selectedMedia.first.path),
                analysisResult: analysisResult,
                postId: null, // No existing post - meal will be created first
                battleId: widget.battleId,
                battleCategory: widget.battleCategory,
                isMainPost: widget.isMainPost,
                selectedCategory: selectedCategory,
                isAnalyzeAndUpload: true,
              ),
            ),
          );
        }
        return; // Early return - don't continue with upload here
      }

      // Regular upload flow (no analysis needed)
      final List<String> uploadedUrls = [];

      for (final media in _selectedMedia) {
        setState(() {
          _uploadProgress = 0.3; // Show initial progress
        });

        String downloadUrl;
        if (_isVideo) {
          // Video is already compressed, upload directly
          downloadUrl = await BattleService.instance.uploadBattleVideo(
            battleId: widget.battleId,
            userId: userService.userId ?? '',
            videoFile: File(media.path),
          );
          setState(() {
            _uploadProgress = 0.8; // Update progress for video upload
          });
        } else {
          // Compress and resize battle image before upload
          final String compressedPath =
              await _compressAndResizeBattleImage(media.path);

          setState(() {
            _uploadProgress = 0.5; // Update progress after compression
          });

          downloadUrl = await BattleService.instance.uploadBattleImage(
            battleId: widget.battleId,
            userId: userService.userId ?? '',
            imageFile: File(compressedPath),
          );

          print('Download url: $downloadUrl');
          // Clean up temporary file
          await File(compressedPath).delete();

          setState(() {
            _uploadProgress = 0.8; // Update progress after upload
          });
        }

        uploadedUrls.add(downloadUrl);
      }

      setState(() {
        _uploadProgress = 0.9; // Almost complete
      });

      final post = Post(
        id: widget.isMainPost
            ? postId.isEmpty
                ? ''
                : postId
            : widget.battleId,
        userId: userService.userId ?? '',
        mediaPaths: uploadedUrls,
        name: userService.currentUser.value?.displayName ?? '',
        category: selectedCategory,
        isBattle: widget.isMainPost ? false : true,
        battleId: widget.isMainPost ? '' : widget.battleCategory,
        isVideo: _isVideo,
      );

      if (widget.isMainPost) {
        await postController.uploadPost(
            post, userService.userId ?? '', uploadedUrls);
      } else {
        await BattleService.instance.uploadBattleImages(post: post);
      }

      setState(() {
        _uploadProgress = 1.0; // Complete
      });

      if (mounted) {
        if (widget.isMainPost) {
          Get.to(() => const BottomNavSec(selectedIndex: 2));
        } else {
          Get.back();
        }
      }
    } catch (e) {
      print('Error uploading battle media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia.isEmpty) {
      return GestureDetector(
        onTap: () => _pickMedia(fromCamera: true),
        child: Container(
          height: MediaQuery.of(context).size.height > 1100
              ? getPercentageHeight(30, context)
              : getPercentageHeight(25, context),
          width: double.infinity,
          decoration: BoxDecoration(
            color: getThemeProvider(context).isDarkMode
                ? kDarkGrey
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Icon(
              Icons.add_a_photo,
              size: getIconScale(15, context),
              color: getThemeProvider(context).isDarkMode
                  ? kWhite.withOpacity(0.7)
                  : kDarkGrey.withOpacity(0.7),
            ),
          ),
        ),
      );
    }

    if (_isVideo) {
      // Use thumbnail preview instead of full video player for better performance
      return Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height > 1100
                ? getPercentageHeight(35, context)
                : getPercentageHeight(30, context),
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _videoThumbnailPath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_videoThumbnailPath!),
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 60,
                              color: kWhite,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam,
                              size: 40,
                              color: kWhite,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Video Ready',
                              style: TextStyle(color: kWhite),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          // File size indicator for videos
          if (_selectedMedia.isNotEmpty)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<int>(
                  future: File(_selectedMedia.first.path).length(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final sizeInMB = snapshot.data! / (1024 * 1024);
                      return Text(
                        '${sizeInMB.toStringAsFixed(1)}MB',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ),
            ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Image.file(
        File(_selectedMedia.first.path),
        height: MediaQuery.of(context).size.height > 1100
            ? getPercentageHeight(35, context)
            : getPercentageHeight(30, context),
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          !widget.isMainPost ? "Upload Battle Media" : "Upload Media",
          style: textTheme.displaySmall?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
              fontSize: getTextScale(7, context)),
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            onPressed: () => _pickMedia(),
            icon: Icon(
              Icons.add,
              size: getIconScale(10, context),
              color: kAccent,
            ),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
        ],
      ),
      body: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
        child: Column(
          children: [
            SizedBox(height: getPercentageHeight(3, context)),
            _buildMediaPreview(),
            SizedBox(height: getPercentageHeight(2, context)),

            // Category Selector
            Obx(() => CategorySelector(
                  categories: helperController.category.value,
                  selectedCategoryId: selectedCategoryId,
                  onCategorySelected: (id, name) {
                    setState(() {
                      selectedCategoryId = id;
                      selectedCategory = name;
                    });
                  },
                  isDarkMode: isDarkMode,
                  accentColor: kAccentLight,
                  darkModeAccentColor: kDarkModeAccent,
                )),

            // Show selected images grid under the recent image
            if (!_isVideo && _selectedMedia.length > 1)
              Container(
                margin: EdgeInsets.only(top: getPercentageHeight(1, context)),
                height: getPercentageHeight(10, context),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMedia.length,
                  itemBuilder: (context, index) {
                    final image = _selectedMedia[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.file(
                        File(image.path),
                        height: getPercentageHeight(10, context),
                        width: getPercentageHeight(10, context),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: getPercentageHeight(3, context)),

            // Description
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: getThemeProvider(context).isDarkMode
                    ? kDarkGrey.withOpacity(0.5)
                    : kWhite.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () {
                  if (!_isVideo) {
                    // For analyze & upload: don't pass a postId, let meal be created first
                    _uploadMedia('analyze_and_upload');
                  } else {
                    showTastySnackbar(
                      'Info',
                      'Video analysis not available! Please use photos.',
                      context,
                      backgroundColor: kRed,
                    );
                  }
                },
                child: Text(
                  'Analyze Food & Upload',
                  style: textTheme.displaySmall?.copyWith(
                      color: _isVideo ? kLightGrey : kAccentLight,
                      fontWeight: FontWeight.w200,
                      fontSize: getTextScale(5.5, context)),
                ),
              ),
            ),

            SizedBox(height: getPercentageHeight(3, context)),

            // Upload progress indicator
            if (isUploading && _uploadProgress > 0)
              Container(
                margin:
                    EdgeInsets.only(bottom: getPercentageHeight(2, context)),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor:
                          isDarkMode ? kDarkGrey : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(kAccent),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${(_uploadProgress * 100).toInt()}% uploaded',
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kBlack,
                        fontSize: getTextScale(3, context),
                      ),
                    ),
                  ],
                ),
              ),

            AppButton(
              onPressed: isUploading ? () {} : () => _uploadMedia(''),
              text: isUploading ? "Uploading..." : "Upload Without Analysis",
              isLoading: isUploading,
              type: AppButtonType.primary,
              width: 100,
            ),
          ],
        ),
      ),
    );
  }
}
