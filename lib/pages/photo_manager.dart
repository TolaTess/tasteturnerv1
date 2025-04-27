import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  List<AssetEntity> _loadedImages = [];
  List<AssetEntity> selectedImages = [];
  final TextEditingController captionController = TextEditingController();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  static const int _batchSize = 20;

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _getTemporaryDirectory().then((dir) {
      if (dir != null) {
        _cleanupTempFiles(dir.path);
      }
    });
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreImages();
    }
  }

  Future<void> _loadMoreImages() async {
    if (_isLoading || _loadedImages.length >= images.length) return;

    setState(() => _isLoading = true);

    final int start = _loadedImages.length;
    final int end =
        start + _batchSize < images.length ? start + _batchSize : images.length;

    await Future.delayed(
        const Duration(milliseconds: 100)); // Prevent UI blocking

    setState(() {
      _loadedImages.addAll(images.sublist(start, end));
      _isLoading = false;
    });
  }

  Future<void> _loadGalleryImages() async {
    try {
      final PermissionState permissionState =
          await PhotoManager.requestPermissionExtend();

      if (!permissionState.hasAccess) {
        PhotoManager.openSetting();
        return;
      }

      // iOS-specific optimization for photo loading
      final FilterOptionGroup filter = FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
          needTitle: true,
        ),
        createTimeCond: DateTimeCond(
          min: DateTime.now().subtract(const Duration(days: 365)),
          max: DateTime.now(),
        ),
      );

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
        filterOption: filter,
      );

      if (albums.isEmpty) {
        print('No photo albums found');
        return;
      }

      final AssetPathEntity recentAlbum = albums[0];

      // Optimize thumbnail loading for iOS
      if (Platform.isIOS) {
        await PhotoManager.setIgnorePermissionCheck(true);
        final List<AssetEntity> galleryImages =
            await recentAlbum.getAssetListRange(
          start: 0,
          end: 100,
        );

        setState(() {
          images = galleryImages;
          _loadedImages = galleryImages.take(_batchSize).toList();
        });
      } else {
        final List<AssetEntity> galleryImages =
            await recentAlbum.getAssetListPaged(
          page: 0,
          size: 100,
        );

        setState(() {
          images = galleryImages;
          _loadedImages = galleryImages.take(_batchSize).toList();
        });
      }
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

    // Get platform-specific settings
    final compressionSettings = await _getCompressionSettings(file);

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: compressionSettings.targetWidth,
      minHeight: compressionSettings.targetHeight,
      quality: compressionSettings.quality,
      format: CompressFormat.jpeg,
      rotate: 0,
      autoCorrectionAngle: true,
      keepExif: false,
    );

    // If still too large, perform second pass compression
    if (compressedFile != null) {
      final compressedSize = await compressedFile.length();
      if (compressedSize > compressionSettings.maxSize) {
        final secondPassPath =
            '${file.parent.path}/compressed_2nd_${DateTime.now().millisecondsSinceEpoch}.jpg';
        return await FlutterImageCompress.compressAndGetFile(
          compressedFile.path,
          secondPassPath,
          minWidth: compressionSettings.secondPassWidth,
          minHeight: compressionSettings.secondPassHeight,
          quality: compressionSettings.secondPassQuality,
          format: CompressFormat.jpeg,
          rotate: 0,
          keepExif: false,
        );
      }
    }

    return compressedFile;
  }

  Future<CompressionSettings> _getCompressionSettings(File file) async {
    final originalFile = await file.readAsBytes();
    final originalImage = await decodeImageFromList(originalFile);
    final int originalWidth = originalImage.width;
    final int originalHeight = originalImage.height;
    final int fileSize = await file.length();

    if (Platform.isIOS) {
      // Get iOS device info for more precise optimization
      final deviceInfo = await DeviceInfoPlugin().iosInfo;
      final bool isModernDevice =
          int.parse(deviceInfo.systemVersion.split('.')[0]) >= 13;

      // Modern iOS devices can handle HEIC better
      if (isModernDevice) {
        return CompressionSettings(
          targetWidth: 1024,
          targetHeight: (1024 * originalHeight / originalWidth).round(),
          quality: fileSize > 5 * 1024 * 1024 ? 75 : 85,
          maxSize: 2 * 1024 * 1024,
          secondPassWidth: 512,
          secondPassHeight: (512 * originalHeight / originalWidth).round(),
          secondPassQuality: 70,
        );
      }
    }

    // Default settings for Android and older iOS devices
    return CompressionSettings(
      targetWidth: 514,
      targetHeight: (514 * originalHeight / originalWidth).round(),
      quality: fileSize > 5 * 1024 * 1024 ? 70 : 85,
      maxSize: 1 * 1024 * 1024,
      secondPassWidth: 412,
      secondPassHeight: (412 * originalHeight / originalWidth).round(),
      secondPassQuality: 60,
    );
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
            child: _loadedImages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                    color: kAccent,
                  ))
                : GridView.builder(
                    controller: _scrollController,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _loadedImages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _loadedImages.length) {
                        return const Center(
                          child: CircularProgressIndicator(color: kAccent),
                        );
                      }

                      final asset = _loadedImages[index];
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
                                thumbnailSize: const ThumbnailSize.square(200),
                                thumbnailFormat: ThumbnailFormat.jpeg,
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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: kAccent),
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
                  isDarkMode ? kLightGrey.withOpacity(0.5) : kAccent,
              foregroundColor: isDarkMode ? kWhite : kAccent,
            ),
            onPressed: _sendImages,
          ),
        ],
      ),
    );
  }

  Future<Directory?> _getTemporaryDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (e) {
      print('Error getting temporary directory: $e');
      return null;
    }
  }

  Future<void> _cleanupTempFiles(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (var entity in dir.list()) {
          if (entity is File && entity.path.contains('compressed_')) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning up temporary files: $e');
    }
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

    // Calculate image dimensions
    final originalFile = await file.readAsBytes();
    final originalImage = await decodeImageFromList(originalFile);
    final int originalWidth = originalImage.width;
    final int originalHeight = originalImage.height;

    // Calculate target dimensions while maintaining aspect ratio
    int targetWidth = 514;
    int targetHeight = (targetWidth * originalHeight / originalWidth).round();

    // Determine quality based on original file size
    final int fileSize = await file.length();
    int quality = 85;

    if (fileSize > 5 * 1024 * 1024) {
      // If larger than 5MB
      quality = 70;
      targetWidth = 412; // Smaller dimension for large files
    } else if (fileSize > 2 * 1024 * 1024) {
      // If larger than 2MB
      quality = 75;
    }

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: quality,
      format: CompressFormat.jpeg, // JPEG typically provides better compression
      rotate: 0,
      autoCorrectionAngle: true,
      keepExif: false, // Remove EXIF data to reduce size
    );

    // If still too large, compress again
    if (compressedFile != null) {
      final compressedSize = await compressedFile.length();
      if (compressedSize > 1 * 1024 * 1024) {
        // If still larger than 1MB
        final secondPassPath =
            '${file.parent.path}/compressed_2nd_${DateTime.now().millisecondsSinceEpoch}.jpg';
        return await FlutterImageCompress.compressAndGetFile(
          compressedFile.path,
          secondPassPath,
          minWidth: targetWidth,
          minHeight: targetHeight,
          quality: 60,
          format: CompressFormat.jpeg,
          rotate: 0,
          keepExif: false,
        );
      }
    }

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

class CompressionSettings {
  final int targetWidth;
  final int targetHeight;
  final int quality;
  final int maxSize;
  final int secondPassWidth;
  final int secondPassHeight;
  final int secondPassQuality;

  CompressionSettings({
    required this.targetWidth,
    required this.targetHeight,
    required this.quality,
    required this.maxSize,
    required this.secondPassWidth,
    required this.secondPassHeight,
    required this.secondPassQuality,
  });
}
