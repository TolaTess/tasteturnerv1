import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/premium_screen.dart';
import '../widgets/avatar_upload.dart';
import '../widgets/profile_form.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  List<XFile> _selectedImages = [];
  XFile? _recentImage;

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
    final user = userService.currentUser;
    final nameController = TextEditingController(text: user?.displayName);
    final bioController = TextEditingController(text: user?.bio);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Edit Profile"),
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Avatar Upload
                  AvatarUpload(
                    avatarUrl: user?.profileImage ?? '',
                    press: () async {
                      List<XFile> pickedImages =
                          await openMultiImagePickerModal(context: context);

                      if (pickedImages.isNotEmpty) {
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

                          Get.snackbar(
                            'Success',
                            'Your image was updated successfully!',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        } catch (e) {
                          print("Error uploading profile image: $e");
                          Get.snackbar(
                            'Error',
                            'Failed to update profile image.',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: user?.isPremium == true ? kGreen : kBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    onPressed: () {
                      if (user?.isPremium == true) {
                        // Do nothing if already premium
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PremiumScreen(),
                          ),
                        );
                      }
                    },
                    child: Text(
                      user?.isPremium == true
                          ? "Premium Access"
                          : "Upgrade to Premium",
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Edit Profile Form
                  EditProfileForm(
                    nameController: nameController,
                    bioController: bioController,
                    press: () {
                      final updatedUser = {
                        'displayName': nameController.text,
                        'bio': bioController.text,
                      };
                      authController.updateUserData(updatedUser);

                      Get.snackbar(
                        'Success',
                        'Your data was updated successfully!',
                        snackPosition: SnackPosition.BOTTOM,
                      );
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
