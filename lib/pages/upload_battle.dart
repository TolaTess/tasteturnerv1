import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../data_models/post_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../service/battle_service.dart';
import '../widgets/category_selector.dart';
import '../service/helper_controller.dart';

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
  List<XFile> _selectedImages = [];
  String selectedCategoryId = '';
  String selectedCategory = 'general';

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

  Future<void> _uploadImage() async {
    if (_selectedImages.isEmpty) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Please select an image first.',
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
      final List<String> uploadedImageUrls = [];

      for (final image in _selectedImages) {
        // Compress and resize battle image before upload
        final String compressedPath =
            await _compressAndResizeBattleImage(image.path);

        // Upload image using battle service
        String downloadUrl = await BattleService.instance.uploadBattleImage(
          battleId: widget.battleId,
          userId: userService.userId ?? '',
          imageFile: File(compressedPath),
        );

        uploadedImageUrls.add(downloadUrl);

        // Clean up temporary file
        await File(compressedPath).delete();
      }

      final post = Post(
        id: widget.isMainPost ? '' : widget.battleId,
        userId: userService.userId ?? '',
        mediaPaths: uploadedImageUrls,
        name: userService.currentUser.value?.displayName ?? '',
        category: selectedCategory,
        isBattle: widget.isMainPost ? false : true,
        battleId: widget.isMainPost ? '' : widget.battleId,
      );

      if (widget.isMainPost) {
        // Move battle from ongoing to voted for the user
        await postController.uploadPost(
            post, userService.userId ?? '', uploadedImageUrls);
      } else {
        // Update battle with uploaded images
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
      print('Error uploading battle image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              !widget.isMainPost
                  ? "Upload Battle Image - ${capitalizeFirstLetter(widget.battleCategory)}"
                  : "Upload Image",
              style: textTheme.titleLarge?.copyWith(color: kAccentLight)),
          leading: InkWell(
            onTap: () => widget.isMainPost
                ? Get.to(() => const BottomNavSec(selectedIndex: 2))
                : Get.back(),
            child: const IconCircleButton(
              isRemoveContainer: true,
            ),
          )),
      body: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(width: getPercentageWidth(2, context)),
                IconButton(
                  onPressed: () async {
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
                          _selectedImages = croppedImages;
                        });
                      }
                    }
                  },
                  icon: Icon(Icons.add, size: getIconScale(10, context)),
                ),
                SizedBox(width: getPercentageWidth(2, context)),
              ],
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            _selectedImages.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      File(_selectedImages.first.path),
                      height: MediaQuery.of(context).size.height > 1100
                          ? getPercentageHeight(35, context)
                          : getPercentageHeight(30, context),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                : GestureDetector(
                    onTap: () async {
                      final XFile? photo = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (photo != null) {
                        final XFile? cropped = await cropImage(photo, context);
                        if (cropped != null) {
                          setState(() {
                            _selectedImages = [cropped];
                          });
                        }
                      }
                    },
                    child: Container(
                      height: MediaQuery.of(context).size.height > 1100
                          ? getPercentageHeight(30, context)
                          : getPercentageHeight(25, context),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDarkMode ? kDarkGrey : Colors.grey[300],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_a_photo,
                          size: getIconScale(15, context),
                          color: isDarkMode
                              ? kWhite.withOpacity(0.7)
                              : kDarkGrey.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),

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
            if (_selectedImages.length > 1)
              Container(
                margin: EdgeInsets.only(top: getPercentageHeight(1, context)),
                height: getPercentageHeight(10, context),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    final image = _selectedImages[index];
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
            ElevatedButton(
              onPressed: isUploading ? null : _uploadImage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor:
                    isDarkMode ? kLightGrey : kAccent.withOpacity(0.50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: isUploading
                  ? const CircularProgressIndicator(
                      color: kAccent,
                    )
                  : Text("Upload", style: textTheme.titleMedium?.copyWith(color: kAccent)),
            ),
          ],
        ),
      ),
    );
  }
}
