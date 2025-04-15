import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../constants.dart';
import '../helper/utils.dart';
import 'safe_text_field.dart';

class CustomImagePickerModal extends StatefulWidget {
  final Function(List<File> images, String? caption) onSend;

  const CustomImagePickerModal({super.key, required this.onSend});

  @override
  State<CustomImagePickerModal> createState() => _CustomImagePickerModalState();
}

class _CustomImagePickerModalState extends State<CustomImagePickerModal> {
  List<AssetEntity> images = [];
  List<AssetEntity> selectedImages = [];
  final TextEditingController captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
  }

  Future<void> _loadGalleryImages() async {
    try {
      final PermissionState permissionState =
          await PhotoManager.requestPermissionExtend();

      if (!permissionState.hasAccess) {
        PhotoManager.openSetting();
        return;
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
          onlyAll: true, type: RequestType.image);

      if (albums.isEmpty) {
        print('No photo albums found');
        return;
      }

      final List<AssetEntity> galleryImages =
          await albums[0].getAssetListPaged(page: 0, size: 50);

      setState(() {
        images = galleryImages;
      });
    } catch (e) {
      print('Error loading gallery images: $e');
      if (mounted) {  
        showTastySnackbar(
          'Try again',
          'Failed to load gallery images. Please check permissions.',
          context,
        );
      }
    }
  }

  Future<File?> _getFile(AssetEntity asset) async {
    return await asset.file;
  }

  Future<XFile?> _compressImage(File file) async {
    final String targetPath =
        '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: 514,
      minHeight: 514,
      quality: 85, // You can adjust quality (0 - 100)
    );

    return compressedFile;
  }

  Future<void> _sendImages() async {
    if (selectedImages.isEmpty) return;

    final List<File> files = [];
    for (var asset in selectedImages) {
      final file = await _getFile(asset);
      if (file != null) {
        final compressedFile = await _compressImage(file);
        if (compressedFile != null) {
          files.add(compressedFile as File);
        } else {
          files.add(file); // fallback if compression fails
        }
      }
    }

    widget.onSend(
      files,
      captionController.text.isNotEmpty ? captionController.text : null,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        color: isDarkMode ? kDarkGrey : kBackgroundColor,
      ),
      child: Column(
        children: [
          const Text(
            'Select Images',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: images.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                    color: kAccent,
                  ))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final asset = images[index];
                      final isSelected = selectedImages.contains(asset);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedImages.remove(asset);
                            } else {
                              selectedImages.add(asset);
                            }
                          });
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AssetEntityImage(
                                asset,
                                isOriginal: false,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (isSelected)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(Icons.check_circle,
                                    color: kAccent, size: 24),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SafeTextFormField(
            controller: captionController,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDarkMode ? kLightGrey : kWhite,
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              hintText: 'Type your caption...',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDarkMode ? kLightGrey.withValues(alpha: 0.5) : kAccent,
              foregroundColor: isDarkMode ? kWhite : kAccent,
            ),
            onPressed: _sendImages,
          ),
        ],
      ),
    );
  }
}

class MultiImagePickerModal extends StatefulWidget {
  final Function(List<File>) onImagesSelected;

  const MultiImagePickerModal({super.key, required this.onImagesSelected});

  @override
  State<MultiImagePickerModal> createState() => _MultiImagePickerModalState();
}

class _MultiImagePickerModalState extends State<MultiImagePickerModal> {
  List<AssetEntity> _galleryImages = [];
  final List<AssetEntity> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
  }

  Future<void> _loadGalleryImages() async {
    try {
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

      if (albums.isEmpty) {
        print('No photo albums found');
        return;
      }

      final List<AssetEntity> recentImages =
          await albums[0].getAssetListPaged(page: 0, size: 50);

      setState(() {
        _galleryImages = recentImages;
      });
    } catch (e) {
      print('Error loading gallery images: $e');
      // Show error message to user if needed
      if (mounted) {
        showTastySnackbar(
          'Try again',
          'Failed to load gallery images. Please check permissions.',
          context,
        );
      }
    }
  }

  Future<XFile?> _compressImage(File file) async {
    final String targetPath =
        '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: 514,
      minHeight: 514,
      quality: 85, // Adjust quality as needed
    );

    return compressedFile;
  }

  Future<void> _onConfirmSelection() async {
    List<File> selectedFiles = [];

    for (AssetEntity entity in _selectedImages) {
      final File? file = await entity.file;
      if (file != null) {
        final compressedFile = await _compressImage(file);
        if (compressedFile != null) {
          selectedFiles.add(File(compressedFile.path));
        } else {
          selectedFiles.add(file); // fallback if compression fails
        }
      }
    }

    widget.onImagesSelected(selectedFiles);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Container(
      color: isDarkMode ? kDarkGrey : kWhite,
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Text(
            'Select Images',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _galleryImages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                    color: kAccent,
                  ))
                : GridView.builder(
                    itemCount: _galleryImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final asset = _galleryImages[index];
                      final isSelected = _selectedImages.contains(asset);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedImages.remove(asset);
                            } else {
                              _selectedImages.add(asset);
                            }
                          });
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AssetEntityImage(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(200),
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (isSelected)
                              const Positioned(
                                top: 5,
                                right: 5,
                                child: Icon(
                                  Icons.check_circle,
                                  color: kAccent,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          ElevatedButton(
            onPressed: _selectedImages.isNotEmpty ? _onConfirmSelection : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor:
                  isDarkMode ? kLightGrey : kAccent.withOpacity(0.50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Text(
              'Confirm Selection',
              style: TextStyle(
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
