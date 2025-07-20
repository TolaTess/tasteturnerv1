import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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

  Future<void> _pickMedia({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();

    final choice =
        await showMediaSelectionDialog(isCamera: fromCamera, context: context, isVideo: true);
    if (choice == null) return;

    if (fromCamera) {
      final XFile? media = choice == 'photo'
          ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80)
          : await picker.pickVideo(source: ImageSource.camera, maxDuration: Duration(seconds: 5));

      if (media != null) {
        if (choice == 'photo') {
          XFile? cropped = await cropImage(media, context);
          if (cropped != null) {
            setState(() {
              _selectedMedia = [cropped];
              _isVideo = false;
            });
          }
        } else {
          setState(() {
            _selectedMedia = [media];
            _isVideo = true;
          });
        }
      }
    } else {
      if (choice == 'photos') {
        List<XFile> pickedImages =
            await openMultiImagePickerModal(context: context);
        if (pickedImages.isNotEmpty) {
          List<XFile> croppedImages = [];
          for (final img in pickedImages) {
            final XFile? cropped = await cropImage(img, context);
            if (cropped != null) {
              croppedImages.add(cropped);
            }
          }
          if (croppedImages.isNotEmpty) {
            setState(() {
              _selectedMedia = croppedImages;
              _isVideo = false;
            });
          }
        }
      } else {
        final XFile? video =
            await picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          setState(() {
            _selectedMedia = [video];
            _isVideo = true;
          });
        }
      }
    }
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

    setState(() => isUploading = true);

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
              ),
            ),
          );
        }
        return; // Early return - don't continue with upload here
      }

      // Regular upload flow (no analysis needed)
      final List<String> uploadedUrls = [];

      for (final media in _selectedMedia) {
        String downloadUrl;
        if (_isVideo) {
          // Upload video directly
          downloadUrl = await BattleService.instance.uploadBattleVideo(
            battleId: widget.battleId,
            userId: userService.userId ?? '',
            videoFile: File(media.path),
          );
        } else {
          // Compress and resize battle image before upload
          final String compressedPath =
              await _compressAndResizeBattleImage(media.path);
          downloadUrl = await BattleService.instance.uploadBattleImage(
            battleId: widget.battleId,
            userId: userService.userId ?? '',
            imageFile: File(compressedPath),
          );

          print('Download url: $downloadUrl');
          // Clean up temporary file
          await File(compressedPath).delete();
        }

        uploadedUrls.add(downloadUrl);
      }

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
        setState(() => isUploading = false);
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
      return Container(
        height: MediaQuery.of(context).size.height > 1100
            ? getPercentageHeight(35, context)
            : getPercentageHeight(30, context),
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: VideoPlayerWidget(
            videoUrl: _selectedMedia.first.path,
            autoPlay: false,
          ),
        ),
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
