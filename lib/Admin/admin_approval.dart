import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:recycleapp/services/database.dart';

class AdminApproval extends StatefulWidget {
  final Function(String requestId, Map<String, dynamic> requestData)?
  onRequestApproved;

  const AdminApproval({super.key, this.onRequestApproved});

  @override
  State<AdminApproval> createState() => _AdminApprovalState();
}

class _AdminApprovalState extends State<AdminApproval> {
  Stream? approvalStream;
  bool _isLoading = true;
  int _totalPendingRequests = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadApprovals();
    _loadPendingCount();
  }

  // NEW: Load total pending count for better UX
  Future<void> _loadPendingCount() async {
    try {
      final querySnapshot =
          await _firestore
              .collection("Requests")
              .where("Status", isEqualTo: "Pending")
              .get();

      if (mounted) {
        setState(() {
          _totalPendingRequests = querySnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error loading pending count: $e');
    }
  }

  Future<void> _loadApprovals() async {
    print("Loading approvals from database...");
    try {
      approvalStream = await DatabaseMethods().getAdminApproval();
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("Approvals loaded, stream active");
    } catch (e) {
      print("Error loading approvals: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _showErrorSnackBar("Failed to load requests");
    }
  }

  // NEW: Enhanced user points retrieval with error handling
  Future<String> getUserPoints(String userId) async {
    try {
      DocumentSnapshot docSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (docSnapshot.exists) {
        var data = docSnapshot.data() as Map<String, dynamic>;
        var points = data['Points'] ?? '0';
        return points.toString();
      }
      return '0';
    } catch (e) {
      print('Error getting user points: $e');
      return '0';
    }
  }

  // UPGRADED: Enhanced approve request with better data collection
  Future<void> _approveRequest(DocumentSnapshot ds) async {
    bool shouldProceed = await _showConfirmationDialog(
      "Approve Request",
      "Are you sure you want to approve this collection request? User will receive reward points.",
    );

    if (!shouldProceed) return;

    try {
      print("Approving request: ${ds.id}");

      // Get current user points
      String userPoints = await getUserPoints(ds["UserId"]);

      // Calculate points based on quantity (assuming 10 points per kg)
      int quantity = int.tryParse(ds["Quantity"] ?? "0") ?? 0;
      int pointsToAdd = quantity * 10;

      // Prepare request data for collections
      Map<String, dynamic> requestData = _prepareCollectionData(
        ds,
        pointsToAdd,
      );

      // Update user points
      int updatedPoints = int.parse(userPoints) + pointsToAdd;
      await DatabaseMethods().updateUserPoints(
        ds["UserId"],
        updatedPoints.toString(),
      );

      // Update request status in both collections
      await DatabaseMethods().updateAdminRequest(ds.id);
      await DatabaseMethods().updateUserRequest(ds["UserId"], ds.id);

      // NEW: Add to Collections for analytics
      await _addToCollections(ds.id, requestData);

      // UPGRADED: Call the callback with proper data
      if (widget.onRequestApproved != null) {
        widget.onRequestApproved!(ds.id, requestData);
      }

      // Show success message
      _showSuccessSnackBar("Request approved! User earned $pointsToAdd points");

      // Refresh the list and count
      _loadApprovals();
      _loadPendingCount();
    } catch (e) {
      print('Error approving request: $e');
      _showErrorSnackBar("Error approving request: ${e.toString()}");
    }
  }

  // NEW: Prepare collection data for analytics
  Map<String, dynamic> _prepareCollectionData(
    DocumentSnapshot ds,
    int pointsEarned,
  ) {
    return {
      "userId": _getFieldValue(ds, "UserId"),
      "userName": _getFieldValue(ds, "Name", defaultValue: "Unknown User"),
      "address": _getFieldValue(
        ds,
        "Address",
        defaultValue: "No address provided",
      ),
      "wasteType": _getFieldValue(ds, "Category", defaultValue: "Unknown"),
      "quantity":
          int.tryParse(_getFieldValue(ds, "Quantity", defaultValue: "0")) ?? 0,
      "pointsEarned": pointsEarned,
      "collectionDate": FieldValue.serverTimestamp(),
      "status": "completed",
      "approvedBy": "admin", // You can replace with actual admin ID
      "requestId": ds.id,
      "createdAt": FieldValue.serverTimestamp(),
      "imageAvailable": _getFieldValue(ds, "Image").isNotEmpty,
    };
  }

  // NEW: Add to Collections collection for tracking
  Future<void> _addToCollections(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection("Collections").doc(requestId).set(data);
      print("Added to Collections: $requestId");
    } catch (e) {
      print("Error adding to collections: $e");
      throw e; // Re-throw to handle in calling method
    }
  }

  // UPGRADED: Enhanced reject request with better UX
  Future<void> _rejectRequest(DocumentSnapshot ds) async {
    bool confirmReject = await _showConfirmationDialog(
      "Reject Request",
      "Are you sure you want to reject this request? This action cannot be undone.",
      isDestructive: true,
    );

    if (confirmReject) {
      await _performRejection(ds);
    }
  }

  // NEW: Separate rejection logic for better organization
  Future<void> _performRejection(DocumentSnapshot ds) async {
    try {
      print("Rejecting request: ${ds.id}");

      // Delete from admin requests collection
      await _firestore.collection("Requests").doc(ds.id).delete();

      // Also update the user's item status to "Rejected"
      await _firestore
          .collection("users")
          .doc(ds["UserId"])
          .collection("Items")
          .doc(ds.id)
          .update({"Status": "Rejected"});

      // Show success message
      _showSuccessSnackBar("Request rejected successfully", isWarning: true);

      // Refresh the list and count
      _loadApprovals();
      _loadPendingCount();
    } catch (e) {
      print('Error rejecting request: $e');
      _showErrorSnackBar("Error rejecting request: ${e.toString()}");
    }
  }

  // NEW: Reusable confirmation dialog
  Future<bool> _showConfirmationDialog(
    String title,
    String content, {
    bool isDestructive = false,
  }) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: isDestructive ? Colors.red : Colors.green,
                  ),
                  child: Text(isDestructive ? "Reject" : "Approve"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // NEW: Reusable snackbar methods
  void _showSuccessSnackBar(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isWarning ? Colors.orange : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Safe data access method to prevent errors
  String _getFieldValue(
    DocumentSnapshot ds,
    String fieldName, {
    String defaultValue = "",
  }) {
    try {
      final data = ds.data() as Map<String, dynamic>?;
      if (data != null &&
          data.containsKey(fieldName) &&
          data[fieldName] != null) {
        return data[fieldName].toString();
      }
      return defaultValue;
    } catch (e) {
      print("Error getting field '$fieldName': $e");
      return defaultValue;
    }
  }

  // NEW: Enhanced debug method with conditional logging
  void _debugDocumentData(DocumentSnapshot ds) {
    if (!kDebugMode) return; // Only run in debug mode

    print("=== DEBUG DOCUMENT DATA ===");
    print("Document ID: ${ds.id}");
    final data = ds.data() as Map<String, dynamic>?;
    if (data != null) {
      data.forEach((key, value) {
        if (key == "Image") {
          print("$key: [BASE64 DATA - LENGTH: ${value.toString().length}]");
        } else {
          print("$key: $value (Type: ${value.runtimeType})");
        }
      });
    } else {
      print("Document data is null");
    }
    print("=== END DEBUG ===");
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera, size: 30, color: Colors.grey[600]),
          const SizedBox(height: 8),
          Text(
            "No Image",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // UPGRADED: Enhanced image widget with better caching and error handling
  Widget _buildImageWidget(DocumentSnapshot ds) {
    String imageData = _getFieldValue(ds, "Image");
    String imageType = _getFieldValue(ds, "ImageType");

    if ((imageType == "base64" || imageData.startsWith('data:image')) &&
        imageData.isNotEmpty) {
      try {
        String base64String =
            imageData.contains(',') ? imageData.split(',').last : imageData;

        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(base64String),
              fit: BoxFit.cover,
              gaplessPlayback: true, // NEW: Prevents flickering
              errorBuilder: (context, error, stackTrace) {
                print("Base64 image error: $error");
                return _buildPlaceholderImage();
              },
            ),
          ),
        );
      } catch (e) {
        print("Error decoding base64: $e");
        return _buildPlaceholderImage();
      }
    } else if (imageData.isNotEmpty && imageData.startsWith('http')) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageData,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print("URL image error: $error");
              return _buildPlaceholderImage();
            },
          ),
        ),
      );
    } else {
      return _buildPlaceholderImage();
    }
  }

  // NEW: Build points indicator widget
  Widget _buildPointsIndicator(int quantity) {
    int points = quantity * 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 14, color: Colors.green[700]),
          const SizedBox(width: 4),
          Text(
            "+$points pts",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  // UPGRADED: Enhanced approval item with better layout
  Widget _buildApprovalItem(DocumentSnapshot ds) {
    _debugDocumentData(ds);

    String userName = _getFieldValue(ds, "Name", defaultValue: "Unknown User");
    String address = _getFieldValue(
      ds,
      "Address",
      defaultValue: "No address provided",
    );
    String quantity = _getFieldValue(ds, "Quantity", defaultValue: "0");
    String category = _getFieldValue(ds, "Category", defaultValue: "Unknown");
    String userId = _getFieldValue(ds, "UserId");
    int quantityInt = int.tryParse(quantity) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            _buildImageWidget(ds),
            const SizedBox(width: 16),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name and Points Indicator
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildPointsIndicator(quantityInt),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quantity and Category
                  Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "$quantity kg",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.category, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      // Reject Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectRequest(ds),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text(
                            "Reject",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Approve Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveRequest(ds),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text(
                            "Approve",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsList() {
    return StreamBuilder(
      stream: approvalStream,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  "Error loading requests",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadApprovals,
                  child: const Text("Try Again"),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "No pending approvals",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "All requests have been processed",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot ds = snapshot.data.docs[index];
            return _buildApprovalItem(ds);
          },
        );
      },
    );
  }

  // NEW: Build custom app bar with pending count
  AppBar _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Collection Approvals"),
          if (_totalPendingRequests > 0)
            Text(
              "$_totalPendingRequests pending",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      backgroundColor: Colors.green[700],
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // NEW: Badge for pending count
        if (_totalPendingRequests > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.red,
              radius: 12,
              child: Text(
                _totalPendingRequests > 99
                    ? "99+"
                    : _totalPendingRequests.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadApprovals,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadApprovals,
                child: _buildApprovalsList(),
              ),
    );
  }
}
