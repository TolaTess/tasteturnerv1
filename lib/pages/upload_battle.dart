import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../data_models/post_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import '../service/battle_service.dart';
import '../widgets/category_selector.dart';
import '../service/helper_controller.dart';
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

  @override
  void initState() {
    super.initState();
    selectedCategory = HelperController.instance.category.value.isNotEmpty
        ? HelperController.instance.category.value.first['name'] ?? 'general'
        : 'general';
    selectedCategoryId = HelperController.instance.category.value.isNotEmpty
        ? HelperController.instance.category.value.first['id'] ?? ''
        : '';
  }

  Future<String?> _showMediaSelectionDialog({required bool isCamera}) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = getThemeProvider(context).isDarkMode;
        final textTheme = Theme.of(context).textTheme;

        final title = isCamera ? 'Choose capture mode' : 'Choose media type';
        final options = isCamera
            ? [
                {
                  'icon': Icons.photo_camera,
                  'title': 'Take Photo',
                  'value': 'photo'
                },
                {
                  'icon': Icons.videocam,
                  'title': 'Record Video',
                  'value': 'video'
                },
              ]
            : [
                {'icon': Icons.photo, 'title': 'Photos', 'value': 'photos'},
                {
                  'icon': Icons.video_library,
                  'title': 'Video',
                  'value': 'video'
                },
              ];

        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            title,
            style: textTheme.titleLarge?.copyWith(color: kAccentLight),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map((option) => ListTile(
                      leading: Icon(
                        option['icon'] as IconData,
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                      title: Text(
                        option['title'] as String,
                        style: textTheme.titleMedium?.copyWith(
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                      ),
                      onTap: () =>
                          Navigator.pop(context, option['value'] as String),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _pickMedia({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();

    final choice = await _showMediaSelectionDialog(isCamera: fromCamera);
    if (choice == null) return;

    if (fromCamera) {
      final XFile? media = choice == 'photo'
          ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80)
          : await picker.pickVideo(source: ImageSource.camera);

      if (media != null) {
        if (choice == 'photo') {
          final XFile? cropped = await cropImage(media, context);
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

  Future<void> _uploadMedia() async {
    if (_selectedMedia.isEmpty) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Please select media first.',
          context,
        );
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

    try {
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
          // Clean up temporary file
          await File(compressedPath).delete();
        }

        uploadedUrls.add(downloadUrl);
      }

      final post = Post(
        id: widget.isMainPost ? '' : widget.battleId,
        userId: userService.userId ?? '',
        mediaPaths: uploadedUrls,
        name: userService.currentUser.value?.displayName ?? '',
        category: selectedCategory,
        isBattle: widget.isMainPost ? false : true,
        battleId: widget.isMainPost ? '' : widget.battleId,
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
          !widget.isMainPost
              ? "Upload Battle Media - ${capitalizeFirstLetter(widget.battleCategory)}"
              : "Upload Media",
          style: textTheme.displaySmall
              ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
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
            SizedBox(height: getPercentageHeight(1, context)),
            _buildMediaPreview(),
            SizedBox(height: getPercentageHeight(2, context)),

            // Category Selector
            Obx(() => CategorySelector(
                  categories: HelperController.instance.category.value,
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
            AppButton(
              onPressed: isUploading ? () {} : () => _uploadMedia(),
              text: isUploading ? "Uploading..." : "Upload",
              isLoading: isUploading,
            ),
          ],
        ),
      ),
    );
  }
}
