import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:recycleapp/Driver/upload_item.dart';
import 'package:recycleapp/Driver/truck_driver_app.dart';
import 'package:recycleapp/services/database.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'package:recycleapp/Driver/maps.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? userId, userName;
  Stream? pendingRequestsStream;
  Map<String, dynamic>? _assignedTruck;
  bool isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    if (userId != null) {
      pendingRequestsStream = await DatabaseMethods().getUserPendingRequests(
        userId!,
      );
      _loadAssignedTruck();
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadUserData() async {
    userId = await SharedpreferenceHelper().getUserId();
    userName = await SharedpreferenceHelper().getUserName();
  }

  void _loadAssignedTruck() {
    if (userId == null) return;

    _firestore
        .collection("Trucks")
        .where("driverId", isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              if (snapshot.docs.isNotEmpty) {
                final doc = snapshot.docs.first;
                _assignedTruck = {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                };
              } else {
                _assignedTruck = null;
              }
            });
          }
        });
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Maintenance':
        return Colors.orange;
      case 'Available':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Show truck assignment dialog
  void _showTruckAssignmentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.05),
            constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Request Truck Assignment',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.05
                            : screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        _firestore
                            .collection("Trucks")
                            .where("status", isEqualTo: "Available")
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: screenWidth * 0.15,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            Text(
                              'No Available Trucks',
                              style: TextStyle(
                                fontSize:
                                    isSmallScreen
                                        ? screenWidth * 0.045
                                        : screenWidth * 0.05,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Text(
                              'All trucks are currently assigned or under maintenance',
                              style: TextStyle(
                                fontSize:
                                    isSmallScreen
                                        ? screenWidth * 0.035
                                        : screenWidth * 0.04,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final truck = snapshot.data!.docs[index];
                          final data = truck.data() as Map<String, dynamic>;

                          return Card(
                            margin: EdgeInsets.only(
                              bottom: screenHeight * 0.01,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.local_shipping,
                                color: Colors.green[700],
                                size: screenWidth * 0.06,
                              ),
                              title: Text(
                                data['licensePlate'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      isSmallScreen
                                          ? screenWidth * 0.04
                                          : screenWidth * 0.045,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Capacity: ${data['capacity']}',
                                    style: TextStyle(
                                      fontSize:
                                          isSmallScreen
                                              ? screenWidth * 0.035
                                              : screenWidth * 0.04,
                                    ),
                                  ),
                                  Text(
                                    'Type: ${data['truckType'] ?? 'Not specified'}',
                                    style: TextStyle(
                                      fontSize:
                                          isSmallScreen
                                              ? screenWidth * 0.035
                                              : screenWidth * 0.04,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward,
                                size: screenWidth * 0.05,
                              ),
                              onTap: () {
                                _submitTruckAssignmentRequest(
                                  truck.id,
                                  data['licensePlate'],
                                  data['capacity'],
                                  data['truckType'] ?? 'Not specified',
                                );
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize:
                              isSmallScreen
                                  ? screenWidth * 0.04
                                  : screenWidth * 0.045,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Submit truck assignment request to Firestore
  Future<void> _submitTruckAssignmentRequest(
    String truckId,
    String licensePlate,
    String capacity,
    String truckType,
  ) async {
    try {
      final assignmentRequestData = {
        'truckId': truckId,
        'licensePlate': licensePlate,
        'capacity': capacity,
        'truckType': truckType,
        'driverId': userId,
        'driverName': userName,
        'requestStatus': 'Pending',
        'requestDate': FieldValue.serverTimestamp(),
        'requestType': 'truck_assignment',
      };

      await _firestore
          .collection("TruckAssignmentRequests")
          .add(assignmentRequestData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Truck assignment request submitted for admin approval!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Check if driver has pending truck assignment requests
  Widget _buildTruckRequestStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection("TruckAssignmentRequests")
              .where("driverId", isEqualTo: userId)
              .where("requestStatus", isEqualTo: "Pending")
              .snapshots(),
      builder: (context, snapshot) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          return Container(
            margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenWidth * 0.03,
            ),
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  color: Colors.orange[700],
                  size: screenWidth * 0.06,
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Truck Assignment Pending',
                        style: TextStyle(
                          fontSize:
                              isSmallScreen
                                  ? screenWidth * 0.04
                                  : screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      Text(
                        'Your truck assignment is under admin review',
                        style: TextStyle(
                          fontSize:
                              isSmallScreen
                                  ? screenWidth * 0.033
                                  : screenWidth * 0.038,
                          color: Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: screenWidth * 0.045,
                  color: Colors.orange[700],
                ),
              ],
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  // Build truck status indicator for assigned truck
  Widget _buildTruckStatusIndicator() {
    if (_assignedTruck == null) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    Color statusColor = _getStatusColor(_assignedTruck!['status']);

    return Container(
      margin: EdgeInsets.only(top: screenWidth * 0.02),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenWidth * 0.015,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: screenWidth * 0.02,
            height: screenWidth * 0.02,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: screenWidth * 0.015),
          Text(
            _assignedTruck!['status'],
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 219, 239, 220),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? screenWidth * 0.12 : screenWidth * 0.14,
            height: isSmallScreen ? screenWidth * 0.12 : screenWidth * 0.14,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 6, 65, 11),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco,
              color: const Color.fromARGB(255, 226, 125, 43),
              size: isSmallScreen ? screenWidth * 0.06 : screenWidth * 0.08,
            ),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello,",
                  style: TextStyle(
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.035
                            : screenWidth * 0.04,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  userName ?? "Eco Warrior",
                  style: TextStyle(
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.045
                            : screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                if (_assignedTruck != null) ...[
                  Text(
                    "Truck: ${_assignedTruck!['licensePlate']}",
                    style: TextStyle(
                      fontSize:
                          isSmallScreen
                              ? screenWidth * 0.03
                              : screenWidth * 0.035,
                      color: Colors.green[600],
                    ),
                  ),
                  _buildTruckStatusIndicator(),
                ],
              ],
            ),
          ),
          if (_assignedTruck != null)
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.local_shipping,
                    color: Colors.green[700],
                    size:
                        isSmallScreen ? screenWidth * 0.07 : screenWidth * 0.08,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TruckDriverApp(),
                      ),
                    );
                  },
                  tooltip: 'Manage Truck Status - ${_assignedTruck!['status']}',
                ),
                Positioned(
                  right: screenWidth * 0.02,
                  top: screenWidth * 0.02,
                  child: Container(
                    width: screenWidth * 0.03,
                    height: screenWidth * 0.03,
                    decoration: BoxDecoration(
                      color: _getStatusColor(_assignedTruck!['status']),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: Icon(
                Icons.local_shipping,
                color: Colors.orange[700],
                size: isSmallScreen ? screenWidth * 0.08 : screenWidth * 0.09,
              ),
              onPressed: _showTruckAssignmentDialog,
              tooltip: 'Request Truck Assignment',
            ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.green[700],
              size: isSmallScreen ? screenWidth * 0.06 : screenWidth * 0.07,
            ),
            onPressed: _initializeData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;
    final bool showImage =
        screenWidth > 350; // Hide image on very small screens

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.02,
      ),
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[700]!, Colors.green[500]!],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "EcoChange For Collectors",
                  style: TextStyle(
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.055
                            : screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "Smarter Waste, Cleaner Streets. Empowering Garbage Collectors on the Move",
                  style: TextStyle(
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.035
                            : screenWidth * 0.04,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                ElevatedButton(
                  onPressed: () {
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  UploadItem(category: "Plastic", id: userId!),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                      vertical: screenHeight * 0.015,
                    ),
                  ),
                  child: Text(
                    "Start Collection",
                    style: TextStyle(
                      fontSize:
                          isSmallScreen
                              ? screenWidth * 0.04
                              : screenWidth * 0.045,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showImage) SizedBox(width: screenWidth * 0.04),
          if (showImage)
            Image.asset(
              "images/home.png",
              height: isSmallScreen ? screenWidth * 0.25 : screenWidth * 0.3,
              width: isSmallScreen ? screenWidth * 0.25 : screenWidth * 0.3,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String categoryName) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    return GestureDetector(
      onTap: () {
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please log in to upload items")),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => UploadItem(category: categoryName, id: userId!),
          ),
        );
      },
      child: Container(
        width: isSmallScreen ? screenWidth * 0.35 : screenWidth * 0.28,
        margin: EdgeInsets.only(right: screenWidth * 0.04),
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.035),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: isSmallScreen ? screenWidth * 0.08 : screenWidth * 0.1,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              categoryName,
              style: TextStyle(
                fontSize:
                    isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Text(
            "Recycle Categories",
            style: TextStyle(
              fontSize:
                  isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.055,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        SizedBox(height: screenWidth * 0.03),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Row(
            children: [
              _buildCategoryItem(Icons.recycling, "Plastic"),
              _buildCategoryItem(Icons.description, "Paper"),
              _buildCategoryItem(Icons.battery_charging_full, "Battery"),
              _buildCategoryItem(Icons.wine_bar, "Glass"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestCard(DocumentSnapshot document) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    final data = document.data() as Map<String, dynamic>;

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: const Color(0xFFD3FFB3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.green[700],
                size: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.055,
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Text(
                  data["Address"] ?? "No address provided",
                  style: TextStyle(
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.04
                            : screenWidth * 0.045,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          Center(
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.recycling,
                size: isSmallScreen ? screenWidth * 0.15 : screenWidth * 0.18,
                color: Colors.green[700],
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.layers,
                color: Colors.green[700],
                size: isSmallScreen ? screenWidth * 0.05 : screenWidth * 0.055,
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                "${data["Quantity"] ?? "0"} kg",
                style: TextStyle(
                  fontSize:
                      isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection() {
    return StreamBuilder(
      stream: pendingRequestsStream,
      builder: (context, AsyncSnapshot snapshot) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(screenWidth * 0.08),
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.recycling,
                  size: isSmallScreen ? screenWidth * 0.15 : screenWidth * 0.2,
                  color: Colors.grey[400],
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  "No pending requests",
                  style: TextStyle(
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.045
                            : screenWidth * 0.05,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "Upload your first item to get started!",
                  style: TextStyle(
                    fontSize:
                        isSmallScreen
                            ? screenWidth * 0.035
                            : screenWidth * 0.04,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot document = snapshot.data.docs[index];
            return _buildPendingRequestCard(document);
          },
        );
      },
    );
  }

  // Build truck info card for quick status overview
  Widget _buildTruckQuickInfo() {
    if (_assignedTruck == null) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.01,
      ),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Truck',
                style: TextStyle(
                  fontSize:
                      isSmallScreen ? screenWidth * 0.045 : screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TruckDriverApp(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Manage',
                        style: TextStyle(
                          fontSize:
                              isSmallScreen
                                  ? screenWidth * 0.033
                                  : screenWidth * 0.035,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.01),
                      Icon(
                        Icons.arrow_forward,
                        size:
                            isSmallScreen
                                ? screenWidth * 0.033
                                : screenWidth * 0.035,
                        color: Colors.green[700],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Row(
            children: [
              Icon(
                Icons.local_shipping,
                color: Colors.green[700],
                size: isSmallScreen ? screenWidth * 0.1 : screenWidth * 0.12,
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _assignedTruck!['licensePlate'],
                      style: TextStyle(
                        fontSize:
                            isSmallScreen
                                ? screenWidth * 0.05
                                : screenWidth * 0.055,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.005),
                    Row(
                      children: [
                        Container(
                          width: screenWidth * 0.02,
                          height: screenWidth * 0.02,
                          decoration: BoxDecoration(
                            color: _getStatusColor(_assignedTruck!['status']),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.015),
                        Text(
                          _assignedTruck!['status'],
                          style: TextStyle(
                            fontSize:
                                isSmallScreen
                                    ? screenWidth * 0.035
                                    : screenWidth * 0.04,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_assignedTruck!['currentLocation'] != null &&
                        _assignedTruck!['currentLocation'] != 'Not specified')
                      Text(
                        _assignedTruck!['currentLocation'],
                        style: TextStyle(
                          fontSize:
                              isSmallScreen
                                  ? screenWidth * 0.03
                                  : screenWidth * 0.035,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToMaps() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapsPage()),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Navigating to Maps page")));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green[700]),
              SizedBox(height: screenHeight * 0.02),
              Text(
                "Loading your eco-profile...",
                style: TextStyle(
                  fontSize:
                      isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _initializeData,
          color: Colors.green[700],
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: screenHeight * 0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildTruckRequestStatus(),
                _buildTruckQuickInfo(),
                _buildHeroSection(),
                SizedBox(height: screenHeight * 0.03),
                _buildCategoriesSection(),
                SizedBox(height: screenHeight * 0.03),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: Text(
                    "Your Pending Requests",
                    style: TextStyle(
                      fontSize:
                          isSmallScreen
                              ? screenWidth * 0.05
                              : screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: _buildPendingRequestsSection(),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToMaps,
        backgroundColor: Colors.green[700],
        child: Icon(Icons.map, color: Colors.white, size: screenWidth * 0.06),
      ),
    );
  }
}
