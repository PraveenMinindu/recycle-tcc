import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:random_string/random_string.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recycleapp/services/database.dart';
import 'package:recycleapp/services/shared_pref.dart';

class UploadItem extends StatefulWidget {
  final String category;
  final String id;

  const UploadItem({required this.category, required this.id, super.key});

  @override
  State<UploadItem> createState() => _UploadItemState();
}

class _UploadItemState extends State<UploadItem> {
  TextEditingController addresscontroller = TextEditingController();
  TextEditingController quantitycontroller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? selectedImage;
  String? userId, userName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    userId = await SharedpreferenceHelper().getUserId();
    userName = await SharedpreferenceHelper().getUserName();
    setState(() {});
  }

  Future<void> _getImageFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400, // Reduced for smaller base64
        maxHeight: 400,
        imageQuality: 40, // Lower quality for smaller size
      );
      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error taking photo: $e")));
    }
  }

  Future<void> _getImageFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400, // Reduced for smaller base64
        maxHeight: 400,
        imageQuality: 40, // Lower quality for smaller size
      );
      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Choose Image Source"),
          content: const Text("Select how you want to add the item image"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _getImageFromCamera();
              },
              child: const Row(
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _getImageFromGallery();
              },
              child: const Row(
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _convertImageToBase64() async {
    if (selectedImage == null) {
      throw Exception("No image selected");
    }

    try {
      // Check if file exists
      bool exists = await selectedImage!.exists();
      if (!exists) {
        throw Exception("Image file not found");
      }

      // Get file size
      int fileSize = await selectedImage!.length();
      print("Image file size: $fileSize bytes");

      // Check if image is too large for Firestore (1MB limit)
      if (fileSize > 800000) {
        // 800KB to be safe
        throw Exception("Image too large. Please select a smaller image");
      }

      // Convert to Base64
      List<int> imageBytes = await selectedImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Create data URL format
      String imageData = "data:image/jpeg;base64,$base64Image";

      print("Base64 conversion successful - Length: ${imageData.length}");

      return imageData;
    } catch (e) {
      print("Image conversion error: $e");
      rethrow;
    }
  }

  Future<void> _uploadItem() async {
    if (addresscontroller.text.isEmpty || quantitycontroller.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please add an image")));
      return;
    }

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      String itemId = randomAlphaNumeric(10);

      // Convert image to Base64 - THIS WAS FAILING SILENTLY
      print("🔄 Converting image to base64...");
      String imageData;
      try {
        imageData = await _convertImageToBase64();
        print("✅ Base64 conversion successful");
      } catch (e) {
        print("❌ Base64 conversion failed: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Image processing failed: $e"),
          ),
        );
        return; // STOP if base64 fails
      }

      Map<String, dynamic> itemData = {
        "Image": imageData,
        "Address": addresscontroller.text,
        "Quantity": quantitycontroller.text,
        "UserId": userId!,
        "Name": userName ?? "Unknown User",
        "Category": widget.category,
        "Status": "Pending",
        "Timestamp": FieldValue.serverTimestamp(),
        "ImageType": "base64",
      };

      print("🔄 Uploading to Firestore...");
      print("User ID: $userId");
      print("Item ID: $itemId");

      // UPLOAD TO BOTH COLLECTIONS
      try {
        // 1. Upload to user's personal collection
        await DatabaseMethods().addUserUploadItem(itemData, userId!, itemId);
        print("✅ Uploaded to user collection");

        // 2. Upload to admin Requests collection
        await DatabaseMethods().addAdminItem(itemData, itemId);
        print("✅ Uploaded to admin Requests collection");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "✅ Upload successful! Admin will review your request.",
            ),
          ),
        );

        // Clear form
        addresscontroller.clear();
        quantitycontroller.clear();
        setState(() => selectedImage = null);

        // Navigate back after success
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } catch (firestoreError) {
        print("❌ Firestore upload error: $firestoreError");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text("Upload failed: $firestoreError"),
          ),
        );
      }
    } catch (e) {
      print("❌ Upload process error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Upload failed: ${e.toString()}"),
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Upload ${widget.category} Item"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body:
          _isUploading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Uploading to admin..."),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Item Image",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              height: 200,
                              width: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child:
                                  selectedImage != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(
                                          selectedImage!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            size: 50,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            "Tap to Add Image",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                          ),
                          if (selectedImage != null)
                            TextButton(
                              onPressed: _showImageSourceDialog,
                              child: const Text(
                                "Change Image",
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      "Pickup Address",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addresscontroller,
                      decoration: InputDecoration(
                        hintText: "Enter complete address for pickup",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      "Quantity (kg)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantitycontroller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter weight in kilograms",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(
                          Icons.scale,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _uploadItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Upload Item",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
