import 'dart:io';
import 'package:fit_hify/constants.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../pages/photo_manager.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';
import 'newpostfinal_screen.dart';

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  List<XFile> _selectedImages = [];
  XFile? _recentImage;

  @override
  void initState() {
    super.initState();
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

  void _toggleMultipleSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return MultiImagePickerModal(
          onImagesSelected: (List<File> selectedFiles) {
            setState(() {
              _selectedImages =
                  selectedFiles.map((file) => XFile(file.path)).toList();

              if (_selectedImages.isNotEmpty) {
                _recentImage = _selectedImages.first;
              }
            });
          },
        );
      },
    );
  }

  void _selectImage(XFile image) {
    setState(() {
      _recentImage = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BottomNavSec()),
          ),
          child: const Icon(Icons.close, size: 28),
        ),
        title: const Text(
          "New Post",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Align(
            alignment: Alignment.center,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewPostScreenFinal(
                      _selectedImages.map((img) => img.path).toList(),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? kLightGrey
                      : kAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child:     Text(
                  "Next",
                  style: TextStyle(
                    color: themeProvider.isDarkMode
                        ?kWhite
                        : kWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ), 
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _recentImage != null
                ? Image.file(
                    File(_recentImage!.path),
                    width: double.infinity,
                    height: 380,
                    fit: BoxFit.cover,
                  )
                : Image.asset(intPlaceholderImage),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Row(
                    children: [
                      Text(
                        "Recents",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.expand_more),
                    ],
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _toggleMultipleSelection,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? kLightGrey
                            : kAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.content_copy,
                            color: themeProvider.isDarkMode
                                ? kWhite
                                : kWhite,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "SELECT MULTIPLE",
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.isDarkMode
                                  ? kWhite
                                  : kWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selected Images GridView
            Expanded(
              child: _selectedImages.isNotEmpty
                  ? GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final image = _selectedImages[index];

                        return GestureDetector(
                          onTap: () => _selectImage(image),
                          child: Stack(
                            children: [
                              Image.file(
                                File(image.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                              if (image.path == _recentImage?.path)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: kAccent,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text('No images selected'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
