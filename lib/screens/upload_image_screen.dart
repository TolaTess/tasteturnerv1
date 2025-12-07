import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:image_picker/image_picker.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../constants.dart';

import '../data_models/post_model.dart';

import '../helper/helper_functions.dart';

import '../helper/utils.dart';

import '../screens/food_analysis_results_screen.dart';

import '../widgets/category_selector.dart';

import '../widgets/primary_button.dart';

class UploadImageScreen extends StatefulWidget {
  const UploadImageScreen({
    super.key,
  });

  @override
  State<UploadImageScreen> createState() => _UploadImageScreenState();
}

class _UploadImageScreenState extends State<UploadImageScreen> {
  bool isUploading = false;

  List<XFile> _selectedMedia = [];

  String selectedCategoryId = '';

  String selectedCategory = 'general';

  double _uploadProgress = 0.0;

  Future<String> _compressAndResizeImage(String imagePath) async {
    // Use shared compression utility for consistent quality and color handling
    return await compressImageForUpload(
      imagePath,
      maxDimension: 1200, // Standard size for post images
    );
  }

  Future<void> _pickMedia({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();

    final choice =
        await showMediaSelectionDialog(isCamera: fromCamera, context: context);

    if (choice == null) return;

    if (choice == 'photo') {
      // Take photo with camera
      final XFile? media = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024, // Limit resolution for faster processing
        maxHeight: 1024,
      );

      if (media != null) {
        XFile? cropped = await cropImage(
            media, context, getThemeProvider(context).isDarkMode);

        if (cropped != null) {
          setState(() {
            _selectedMedia = [cropped];
          });
        }
      }
    } else if (choice == 'gallery' || choice == 'photos') {
      // Use OS native image picker for better performance and reliability
      try {
        List<XFile> pickedImages = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2048, // Higher quality for posts
          maxHeight: 2048,
        );

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
            });
          }
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
    }
  }

  Future<void> _uploadMedia(String postId, {bool isFeedPage = false}) async {
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

    try {
      // If this is for analysis (postId is 'analyze_and_upload'), do analysis FIRST

      if (postId == 'analyze_and_upload') {
        // Show loading dialog for analysis

        if (mounted) {
          showLoadingDialog(context);
        }

        // Analyze the image with AI first

        final analysisResult = await geminiService.analyzeFoodImageWithContext(
          imageFile: File(_selectedMedia.first.path),
          mealType: getMealTimeOfDay(),
        );

        if (mounted) {
          hideLoadingDialog(context); // Close loading dialog
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

                selectedCategory: selectedCategory,

                isAnalyzeAndUpload: true,

                isFeedPage: isFeedPage,
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

        // Compress and resize image before upload

        final String compressedPath = await _compressAndResizeImage(media.path);

        setState(() {
          _uploadProgress = 0.5; // Update progress after compression
        });

        // Upload image to Firebase Storage

        final String fileName =
            '${userService.userId ?? ''}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final storageRef = firebaseStorage.ref().child('post_images/$fileName');

        final uploadTask = storageRef.putFile(File(compressedPath));

        final snapshot = await uploadTask.whenComplete(() => null);

        final String downloadUrl = await snapshot.ref.getDownloadURL();

        // Clean up temporary file

        try {
          await File(compressedPath).delete();
        } catch (e) {
          debugPrint('Error deleting temporary compressed file: $e');

          // Continue execution even if cleanup fails
        }

        setState(() {
          _uploadProgress = 0.8; // Update progress after upload
        });

        uploadedUrls.add(downloadUrl);
      }

      setState(() {
        _uploadProgress = 0.9; // Almost complete
      });

      final post = Post(
        id: '', // Always let Firestore generate unique ID

        userId: userService.userId ?? '',

        mediaPaths: uploadedUrls,

        name: userService.currentUser.value?.displayName ?? '',

        category:
            selectedCategory, // Use actual selected category for all posts
      );

      await postController.uploadPost(
          post, userService.userId ?? '', uploadedUrls);

      setState(() {
        _uploadProgress = 1.0; // Complete
      });

      if (mounted) {
        Get.back();
      }
    } catch (e) {
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
                  ? kWhite.withValues(alpha: 0.7)
                  : kDarkGrey.withValues(alpha: 0.7),
            ),
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
          "Upload Media",
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
                  categories: List<Map<String, dynamic>>.from(
                      helperController.category),
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

            if (_selectedMedia.length > 1)
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
                    ? kDarkGrey.withValues(alpha: 0.5)
                    : kWhite.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () {
                  // For analyze & upload: don't pass a postId, let meal be created first

                  _uploadMedia('analyze_and_upload', isFeedPage: true);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: kAccentLight,
                      size: getIconScale(5, context),
                    ),
                    SizedBox(width: getPercentageWidth(1, context)),
                    Text(
                      'Analyze Food & Upload',
                      style: textTheme.displaySmall?.copyWith(
                          color: kAccentLight,
                          fontWeight: FontWeight.w200,
                          fontSize: getTextScale(5.5, context)),
                    ),
                  ],
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
              onPressed: isUploading
                  ? () {}
                  : () => _uploadMedia('', isFeedPage: true),
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
