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
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/category_selector.dart';
import '../widgets/icon_widget.dart';
import '../service/battle_service.dart';

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
  XFile? _recentImage;
  String selectedCategory = 'all';
  String selectedCategoryId = '';

  void _updateCategoryData(String categoryId, String category) {
    if (!mounted) return;
    setState(() {
      selectedCategoryId = categoryId;
      selectedCategory = category;
    });
  }

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

    final categoryDatasIngredient = helperController.macros;
    if (categoryDatasIngredient.isNotEmpty && selectedCategoryId.isEmpty) {
      selectedCategoryId = categoryDatasIngredient[0]['id'] ?? '';
      selectedCategory = categoryDatasIngredient[0]['name'] ?? '';
    }
    _loadGalleryImages();
  }

  Future<void> _loadGalleryImages() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();

    if (!permission.hasAccess) {
      PhotoManager.openSetting();
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    final List<AssetEntity> recentImages =
        await albums.first.getAssetListPaged(page: 0, size: 1);

    if (recentImages.isNotEmpty) {
      final File? recentFile = await recentImages.first.file;
      if (recentFile != null) {
        setState(() {
          _recentImage = XFile(recentFile.path);
          _selectedImages = [_recentImage!];
        });
      }
    } else {
      setState(() {
        _recentImage = null;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImages.isEmpty) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          '',
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
        name: userService.currentUser?.displayName ?? '',
        category: widget.isMainPost ? selectedCategory : widget.battleCategory,
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
          Get.to(() => const BottomNavSec(selectedIndex: 1));
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
    final categoryDatas = helperController.macros;

    return Scaffold(
      appBar: AppBar(
          title: Text(!widget.isMainPost
              ? "Upload Battle Image - ${capitalizeFirstLetter(widget.battleCategory)}"
              : "Post Image"),
          leading: InkWell(
            onTap: () => widget.isMainPost ? Get.to(() => const BottomNavSec(selectedIndex: 1)) : Get.back(),
            child: const IconCircleButton(
              isRemoveContainer: true,
            ),
          )),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            //category options
            if (widget.isMainPost)
              CategorySelector(
                categories: categoryDatas,
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: _updateCategoryData,
                isDarkMode: isDarkMode,
                accentColor: kAccentLight,
                darkModeAccentColor: kDarkModeAccent,
              ),
            const SizedBox(height: 20),
            _recentImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      File(_recentImage!.path),
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Center(child: Text("No Image Selected")),
                  ),

            // Show selected images grid under the recent image
            if (_selectedImages.length > 1)
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    final image = _selectedImages[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.file(
                        File(image.path),
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () async {
                    final XFile? photo = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (photo != null) {
                      setState(() {
                        _selectedImages = [photo];
                        _recentImage = photo;
                      });
                    }
                  },
                  icon: const Icon(Icons.camera, size: 30),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () async {
                    List<XFile> pickedImages =
                        await openMultiImagePickerModal(context: context);
                    if (pickedImages.isNotEmpty) {
                      setState(() {
                        _selectedImages = pickedImages;
                        _recentImage = _selectedImages.first;
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 30),
                ),
              ],
            ),

            const SizedBox(height: 20),
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
                  ? CircularProgressIndicator(
                      color: isDarkMode ? kAccent : kDarkGrey,
                    )
                  : const Text("Upload Images"),
            ),
          ],
        ),
      ),
    );
  }
}
