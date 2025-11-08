import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:recycleapp/services/shared_pref.dart';

class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _truckIdController = TextEditingController();

  String? _selectedCategory;
  List<XFile> _attachedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _driverId;
  String? _driverName;

  // Truck driver specific complaint categories
  final List<String> _categories = [
    'Truck Mechanical Issue',
    'Route Navigation Problem',
    'Collection Bin Access',
    'Safety Concern',
    'Schedule Conflict',
    'Equipment Malfunction',
    'Road Condition Issue',
    'Customer Cooperation Problem',
    'Waste Overflow',
    'Other Truck Issue',
  ];

  // Priority levels for truck issues
  final List<String> _priorityLevels = ['Low', 'Medium', 'High', 'Urgent'];
  String? _selectedPriority = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    _driverId = await SharedpreferenceHelper().getUserId();
    _driverName = await SharedpreferenceHelper().getUserName();
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _truckIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _attachedImages.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _attachedImages.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to take photo')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
    });
  }

  // Upload image to Firebase Storage and return URL
  Future<String> _uploadImageToStorage(
    File imageFile,
    String complaintId,
    int index,
  ) async {
    try {
      String fileName =
          'complaint_${complaintId}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      Reference storageRef = _storage.ref().child('complaint_images/$fileName');

      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  // Save complaint to Firestore
  Future<void> _saveComplaintToFirestore(List<String> imageUrls) async {
    try {
      String complaintId = _firestore.collection('Complaints').doc().id;

      Map<String, dynamic> complaintData = {
        'id': complaintId,
        'driverId': _driverId,
        'driverName': _driverName,
        'truckLicensePlate': _truckIdController.text,
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'imageUrls': imageUrls,
        'status': 'Pending', // This will show as "Unread" in admin panel
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('Complaints')
          .doc(complaintId)
          .set(complaintData);

      print('Complaint saved successfully: $complaintId');
    } catch (e) {
      print('Error saving complaint: $e');
      throw e;
    }
  }

  void _submitComplaint() async {
    if (_formKey.currentState!.validate()) {
      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.green[700]),
                  const SizedBox(width: 20),
                  const Text("Submitting truck issue..."),
                ],
              ),
            ),
          );
        },
      );

      try {
        List<String> imageUrls = [];

        // Upload images if any
        if (_attachedImages.isNotEmpty) {
          for (int i = 0; i < _attachedImages.length; i++) {
            String imageUrl = await _uploadImageToStorage(
              File(_attachedImages[i].path),
              'temp_complaint_id',
              i,
            );
            imageUrls.add(imageUrl);
          }
        }

        // Save complaint data to Firestore
        await _saveComplaintToFirestore(imageUrls);

        // Close loading dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Truck issue reported successfully! Maintenance team notified.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Clear the form
        _formKey.currentState!.reset();
        setState(() {
          _selectedCategory = null;
          _selectedPriority = 'Medium';
          _attachedImages.clear();
        });

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit complaint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get priority color
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Low':
        return Colors.blue;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.red;
      case 'Urgent':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Truck Issue'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header for truck drivers
              Text(
                'Report Truck Issue',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Report any issues with your assigned truck or collection route',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Truck ID/Plate Number
              Text(
                'Truck License Plate *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _truckIdController,
                decoration: InputDecoration(
                  hintText: 'Enter truck license plate number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: Icon(
                    Icons.local_shipping,
                    color: Colors.green[700],
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter truck license plate';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Issue Category for truck drivers
              Text(
                'Issue Type *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: Icon(Icons.category, color: Colors.green[700]),
                ),
                items:
                    _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select issue type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Priority Level
              Text(
                'Priority Level *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: Icon(
                    Icons.priority_high,
                    color: Colors.green[700],
                  ),
                ),
                items:
                    _priorityLevels.map((String priority) {
                      return DropdownMenuItem<String>(
                        value: priority,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getPriorityColor(priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(priority),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPriority = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select priority level';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Issue Title
              Text(
                'Issue Title *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Brief description of the truck/route issue',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter issue title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Issue Description
              Text(
                'Detailed Description *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Describe the issue in detail. Include any error messages, unusual sounds, or specific problems.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter issue description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Current Location
              Text(
                'Current Location *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'Where is the truck located?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter current location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Attach Images section
              Text(
                'Attach Photos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take photos of the issue (damage, warning lights, etc.)',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Camera button (more important for truck drivers)
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Gallery button
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C698D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Display attached images
              if (_attachedImages.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attached Photos (${_attachedImages.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _attachedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                  image: DecorationImage(
                                    image: FileImage(
                                      File(_attachedImages[index].path),
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 30),

              // Emergency contact info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Contact',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          Text(
                            'For urgent mechanical issues, call maintenance: 555-1234',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitComplaint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Truck Issue Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
