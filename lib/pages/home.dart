import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:recycleapp/pages/upload_item.dart';
import 'package:recycleapp/pages/truck_driver_app.dart';
import 'package:recycleapp/services/database.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'package:recycleapp/pages/maps.dart';

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
        return AlertDialog(
          title: Text(
            'Request Truck Assignment',
            style: TextStyle(color: Colors.green[800]),
          ),
          content: SizedBox(
            width: double.maxFinite,
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
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Available Trucks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All trucks are currently assigned or under maintenance',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select a truck to request assignment:',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 200,
                      child: ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final truck = snapshot.data!.docs[index];
                          final data = truck.data() as Map<String, dynamic>;

                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                Icons.local_shipping,
                                color: Colors.green[700],
                              ),
                              title: Text(
                                data['licensePlate'] ?? 'Unknown',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Capacity: ${data['capacity']}'),
                                  Text(
                                    'Type: ${data['truckType'] ?? 'Not specified'}',
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
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
        'requestStatus': 'Pending', // Pending, Approved, Rejected
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
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Truck Assignment Pending',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      Text(
                        'Your truck assignment is under admin review',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
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

    Color statusColor = _getStatusColor(_assignedTruck!['status']);

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _assignedTruck!['status'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20.0),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 6, 65, 11),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco,
              color: const Color.fromARGB(255, 226, 125, 43),
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello,",
                  style: TextStyle(fontSize: 14.0, color: Colors.grey[600]),
                ),
                Text(
                  userName ?? "Eco Warrior",
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                if (_assignedTruck != null) ...[
                  Text(
                    "Truck: ${_assignedTruck!['licensePlate']}",
                    style: TextStyle(fontSize: 12.0, color: Colors.green[600]),
                  ),
                  _buildTruckStatusIndicator(),
                ],
              ],
            ),
          ),
          // Updated truck status button with indicator
          if (_assignedTruck != null)
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.local_shipping, color: Colors.green[700]),
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
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
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
              icon: Icon(Icons.local_shipping, color: Colors.orange[700]),
              iconSize: 30,
              onPressed: _showTruckAssignmentDialog,
              tooltip: 'Request Truck Assignment',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.green[700]),
            onPressed: _initializeData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      padding: const EdgeInsets.all(25.0),
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
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Smarter Waste, Cleaner Streets. Empowering Garbage Collectors on the Move",
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 20),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    "Start Collection",
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Image.asset("images/home.png", height: 120, width: 120),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String categoryName) {
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
        width: 110,
        margin: const EdgeInsets.only(right: 16.0),
        padding: const EdgeInsets.all(16.0),
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
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 35, color: Colors.green[700]),
            ),
            const SizedBox(height: 12),
            Text(
              categoryName,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            "Recycle Categories",
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
    final data = document.data() as Map<String, dynamic>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
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
              Icon(Icons.location_on, color: Colors.green[700], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data["Address"] ?? "No address provided",
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.recycling, size: 70, color: Colors.green[700]),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.layers, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                "${data["Quantity"] ?? "0"} kg",
                style: TextStyle(fontSize: 16.0, color: Colors.grey[700]),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(30.0),
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.recycling, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 20),
                Text(
                  "No pending requests",
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Upload your first item to get started!",
                  style: TextStyle(fontSize: 14.0, color: Colors.grey[500]),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      padding: const EdgeInsets.all(16.0),
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
                  fontSize: 16,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: Colors.green[700],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.green[700], size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _assignedTruck!['licensePlate'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(_assignedTruck!['status']),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _assignedTruck!['status'],
                          style: TextStyle(
                            fontSize: 14,
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green[700]),
              const SizedBox(height: 20),
              Text(
                "Loading your eco-profile...",
                style: TextStyle(fontSize: 16.0, color: Colors.grey[600]),
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
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildTruckRequestStatus(), // Truck assignment request status
                _buildTruckQuickInfo(), // Quick truck info card
                _buildHeroSection(),
                const SizedBox(height: 30),
                _buildCategoriesSection(),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "Your Pending Requests",
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0),
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
        child: const Icon(Icons.map, color: Colors.white),
      ),
    );
  }
}
