// lib/Admin/news_events_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class NewsEventsManagement extends StatefulWidget {
  const NewsEventsManagement({super.key});

  @override
  State<NewsEventsManagement> createState() => _NewsEventsManagementState();
}

class _NewsEventsManagementState extends State<NewsEventsManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  List<XFile> _selectedImages = [];
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedType = 'news'; // 'news' or 'event'

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('News & Events Management'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: isLargeScreen
          ? _buildLargeScreenLayout(screenWidth)
          : _buildMobileLayout(),
    );
  }

  Widget _buildLargeScreenLayout(double screenWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form Section - Fixed width for large screens
        Container(
          width: screenWidth * 0.4,
          padding: const EdgeInsets.all(16),
          child: _buildAddForm(),
        ),

        // List Section - Flexible width
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildNewsEventsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Add New Form
        Expanded(flex: 2, child: SingleChildScrollView(child: _buildAddForm())),

        // List of existing news & events
        Expanded(flex: 3, child: _buildNewsEventsList()),
      ],
    );
  }

  Widget _buildAddForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Card(
      margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),

            // Type Selection - Responsive layout
            _buildTypeSelection(isSmallScreen),
            SizedBox(height: isSmallScreen ? 12 : 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: isSmallScreen ? 2 : 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Date (for events) or News Date
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: _selectedType == 'event'
                    ? 'Event Date'
                    : 'Publish Date',
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.calendar_today,
                    size: isSmallScreen ? 18 : 24,
                  ),
                  onPressed: _pickDate,
                ),
              ),
            ),

            // Location (for events)
            if (_selectedType == 'event') ...[
              SizedBox(height: isSmallScreen ? 8 : 12),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  border: const OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                ),
              ),
            ],

            SizedBox(height: isSmallScreen ? 12 : 16),

            // Image Picker
            _buildImagePicker(isSmallScreen),

            SizedBox(height: isSmallScreen ? 12 : 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitNewsEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: isSmallScreen ? 16 : 20,
                        height: isSmallScreen ? 16 : 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Submit',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelection(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'News',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            leading: Radio<String>(
              value: 'news',
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 16),
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Event',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            leading: Radio<String>(
              value: 'event',
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),

        // Selected Images Preview
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: isSmallScreen ? 80 : 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: isSmallScreen ? 80 : 100,
                      height: isSmallScreen ? 80 : 100,
                      margin: EdgeInsets.only(right: isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(_selectedImages[index].path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: isSmallScreen ? 8 : 12,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(isSmallScreen ? 3 : 4),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: isSmallScreen ? 12 : 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        SizedBox(height: isSmallScreen ? 6 : 8),

        // Add Image Button
        OutlinedButton(
          onPressed: _pickImages,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 8 : 12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate, size: isSmallScreen ? 16 : 20),
              SizedBox(width: isSmallScreen ? 4 : 8),
              Text(
                'Add Images',
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewsEventsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('news_events')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs;

        if (documents.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No news or events found',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: Colors.grey[600],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final doc = documents[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildNewsEventCard(doc.id, data, isSmallScreen);
          },
        );
      },
    );
  }

  Widget _buildNewsEventCard(
    String id,
    Map<String, dynamic> data,
    bool isSmallScreen,
  ) {
    final isEvent = data['type'] == 'event';
    final imageBase64List = List<String>.from(data['imageBase64'] ?? []);

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type badge
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8,
                    vertical: isSmallScreen ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: isEvent ? Colors.orange : Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isEvent ? 'EVENT' : 'NEWS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Use Builder to create a new context for PopupMenuButton
                Builder(
                  builder: (context) => PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: isSmallScreen ? 18 : 24),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteNewsEvent(id);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: isSmallScreen ? 16 : 20,
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isSmallScreen ? 6 : 8),

            // Title
            Text(
              data['title'] ?? 'No Title',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: isSmallScreen ? 4 : 6),

            // Description
            Text(
              data['description'] ?? 'No Description',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: isSmallScreen ? 6 : 8),

            // Date and Location
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: isSmallScreen ? 14 : 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Expanded(
                  child: Text(
                    data['date'] ?? 'No Date',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isEvent && data['location'] != null) ...[
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Icon(
                    Icons.location_on,
                    size: isSmallScreen ? 14 : 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: isSmallScreen ? 4 : 6),
                  Expanded(
                    child: Text(
                      data['location']!,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            // Images Preview
            if (imageBase64List.isNotEmpty) ...[
              SizedBox(height: isSmallScreen ? 6 : 8),
              SizedBox(
                height: isSmallScreen ? 60 : 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageBase64List.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: isSmallScreen ? 60 : 80,
                      height: isSmallScreen ? 60 : 80,
                      margin: EdgeInsets.only(right: isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        image: DecorationImage(
                          image: MemoryImage(
                            base64Decode(imageBase64List[index]),
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;

        return Theme(
          data: ThemeData.light().copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
            ),
          ),
          child: isSmallScreen
              ? Dialog(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: child,
                  ),
                )
              : child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e');
    }
  }

  // Convert image to Base64
  Future<String> _imageToBase64(XFile image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _submitNewsEvent() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      _showSnackBar('Please fill in all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert images to Base64
      List<String> imageBase64List = [];
      for (var image in _selectedImages) {
        final base64String = await _imageToBase64(image);
        imageBase64List.add(base64String);
      }

      // Create document
      final Map<String, dynamic> newsEventData = {
        'type': _selectedType,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'date': _dateController.text,
        'imageBase64': imageBase64List, // Store as Base64
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add location for events
      if (_selectedType == 'event') {
        newsEventData['location'] = _locationController.text;
      }

      await _firestore.collection('news_events').add(newsEventData);

      // Clear form
      _clearForm();

      _showSnackBar(
        '${_selectedType == 'news' ? 'News' : 'Event'} submitted successfully!',
      );
    } catch (e) {
      _showSnackBar('Error submitting: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNewsEvent(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;

        return AlertDialog(
          title: Text(
            'Confirm Delete',
            style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
          ),
          content: Text(
            'Are you sure you want to delete this item?',
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(
                'Delete',
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Delete from Firestore
        await _firestore.collection('news_events').doc(id).delete();

        _showSnackBar('Item deleted successfully');
      } catch (e) {
        _showSnackBar('Error deleting item: $e');
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _dateController.clear();
    _locationController.clear();
    _selectedImages.clear();
    _selectedType = 'news';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: message.toLowerCase().contains('error')
            ? Colors.red
            : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
