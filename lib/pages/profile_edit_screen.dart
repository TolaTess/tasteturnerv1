import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../widgets/avatar_upload.dart';
import '../widgets/icon_widget.dart';
import '../widgets/profile_form.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  List<XFile> _selectedImages = [];
  XFile? _recentImage;
  String? selectedGender;
  bool _shouldDisableCycleSyncing = false;

  @override
  void initState() {
    super.initState();
    // Initialize selectedGender from user settings
    selectedGender = userService.currentUser.value?.settings['gender'];
  }

  Future<String> _compressAndResizeProfileImage(String imagePath) async {
    // Read the image file
    final File imageFile = File(imagePath);
    final List<int> bytes = await imageFile.readAsBytes();
    final Uint8List uint8Bytes = Uint8List.fromList(bytes);
    final img.Image? image = img.decodeImage(uint8Bytes);

    if (image == null) throw Exception('Failed to decode image');

    // Calculate new dimensions while maintaining aspect ratio
    const int maxDimension = 400; // Maximum dimension for profile images
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
        '${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(tempPath).writeAsBytes(compressedBytes);

    return tempPath;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = userService.currentUser.value;
    final nameController = TextEditingController(text: user?.displayName);
    final bioController = TextEditingController(text: user?.bio);
    final dobController = TextEditingController(text: user?.dob);

    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Get.back(),
          child: const IconCircleButton(),
        ),
        centerTitle: true,
        title: Text("Edit Station",
            style:
                textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500,
                fontSize: getTextScale(7, context))),
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context)),
              child: Column(
                children: [
                  SizedBox(height: getPercentageHeight(2, context)),

                  // Avatar Upload
                  AvatarUpload(
                    avatarUrl: user?.profileImage ?? '',
                    press: () async {
                      List<XFile> pickedImages =
                          await openMultiImagePickerModal(context: context);

                      if (pickedImages.isNotEmpty) {
                        List<XFile> croppedImages = [];
                        for (final img in pickedImages) {
                          final XFile? cropped = await cropImage(
                            img,
                            context,
                            getThemeProvider(context).isDarkMode,
                          );
                          if (cropped != null) {
                            croppedImages.add(cropped);
                          }
                        }
                        setState(() {
                          _selectedImages = pickedImages;
                          _recentImage = _selectedImages.first;
                        });

                        try {
                          final String userId = userService.userId ?? "";
                          if (userId.isEmpty) return;

                          if (_recentImage == null) {
                            throw Exception("No image selected.");
                          }

                          // Compress and resize profile image before upload
                          final String compressedPath =
                              await _compressAndResizeProfileImage(
                                  _recentImage!.path);

                          // Upload Image to Firebase Storage
                          String filePath = 'users/$userId/profileImage.jpg';
                          TaskSnapshot uploadTask = await firebaseStorage
                              .ref(filePath)
                              .putFile(File(compressedPath));

                          // Get Image URL
                          String imageUrl =
                              await uploadTask.ref.getDownloadURL();

                          final updatedUser = {
                            'profileImage': imageUrl,
                          };
                          authController.updateUserData(updatedUser);

                          // Clean up temporary file
                          await File(compressedPath).delete();

                          showTastySnackbar(
                            'Service Approved',
                            'Your image was updated successfully, Chef!',
                            context,
                          );
                        } catch (e) {
                          if (mounted) {
                            showTastySnackbar(
                              'Service Error',
                              'Failed to update profile image, Chef. Please try again.',
                              context,
                            );
                          }
                        }
                      }
                    },
                  ),

                  SizedBox(height: getPercentageHeight(5, context)),

                  // Edit Profile Form
                  EditProfileForm(
                    nameController: nameController,
                    bioController: bioController,
                    dobController: dobController,
                    onGenderChanged: (gender) async {
                      // Check if changing to male and cycle syncing is enabled
                      if (gender?.toLowerCase() == 'male') {
                        final currentUser = userService.currentUser.value;
                        final cycleData = currentUser?.settings['cycleTracking'];
                        final isCycleSyncingEnabled = cycleData != null &&
                            cycleData is Map &&
                            (cycleData['isEnabled'] as bool? ?? false);
                        
                        if (isCycleSyncingEnabled) {
                          // Show dialog to inform user
                          final shouldProceed = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) {
                              final isDarkMode = getThemeProvider(context).isDarkMode;
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                                title: Text(
                                  'Cycle Syncing Will Be Disabled',
                                  style: TextStyle(
                                    color: isDarkMode ? kWhite : kBlack,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                content: Text(
                                  'Since you\'re changing your gender to male, Chef, cycle syncing will be automatically disabled as it\'s only available for female users.',
                                  style: TextStyle(
                                    color: isDarkMode ? kLightGrey : kDarkGrey,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: isDarkMode ? kWhite : kDarkGrey,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, true),
                                    child: Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: kAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (shouldProceed == true) {
                            setState(() {
                              selectedGender = gender;
                              _shouldDisableCycleSyncing = true;
                            });
                          }
                          // If user cancels, don't change gender
                        } else {
                          // Cycle syncing not enabled, just update gender
                          setState(() {
                            selectedGender = gender;
                          });
                        }
                      } else {
                        // Not changing to male, just update gender
                        setState(() {
                          selectedGender = gender;
                          _shouldDisableCycleSyncing = false;
                        });
                      }
                    },
                    press: () {
                      final updatedUser = <String, dynamic>{
                        'displayName': nameController.text,
                        'bio': bioController.text,
                        'dob': dobController.text,
                        'settings.gender': selectedGender,
                      };
                      
                      // If changing to male and cycle syncing should be disabled
                      if (_shouldDisableCycleSyncing && selectedGender?.toLowerCase() == 'male') {
                        // Get current cycle tracking data
                        final currentUser = userService.currentUser.value;
                        final currentCycleData = currentUser?.settings['cycleTracking'];
                        
                        // Disable cycle syncing while preserving other cycle data
                        if (currentCycleData != null && currentCycleData is Map) {
                          final updatedCycleData = Map<String, dynamic>.from(currentCycleData);
                          updatedCycleData['isEnabled'] = false;
                          updatedUser['settings.cycleTracking'] = updatedCycleData;
                        } else {
                          // Create new cycle tracking data with disabled state
                          updatedUser['settings.cycleTracking'] = {
                            'isEnabled': false,
                            'cycleLength': 28,
                          };
                        }
                      }
                      
                      authController.updateUserData(updatedUser);

                      showTastySnackbar(
                        'Service Approved',
                        'Your data was updated successfully, Chef!',
                        context,
                      );
                      
                      // Reset flag
                      setState(() {
                        _shouldDisableCycleSyncing = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
