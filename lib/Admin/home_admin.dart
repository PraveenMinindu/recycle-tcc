import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:recycleapp/Admin/admin_approval.dart';
import 'package:recycleapp/Admin/truckmanagement.dart';
import 'package:recycleapp/Admin/collection_analytics.dart';
import 'package:recycleapp/Admin/route_optimization.dart';
import 'package:recycleapp/Admin/complaint_management.dart';
import 'dart:async';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  int pendingRequests = 0;
  int completedToday = 0;
  int activeTrucks = 0;
  int pendingComplaints = 0;
  double totalKilograms = 0.0;
  double todayKilograms = 0.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _collectionsSubscription;
  StreamSubscription? _todayCollectionsSubscription;
  StreamSubscription? _trucksSubscription;
  StreamSubscription? _complaintsSubscription;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    _loadTotalKilograms();
    _loadTodayKilograms();
    _loadActiveTrucks();
    _loadPendingComplaints();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _collectionsSubscription?.cancel();
    _todayCollectionsSubscription?.cancel();
    _trucksSubscription?.cancel();
    _complaintsSubscription?.cancel();
    super.dispose();
  }

  // Load pending requests count from Firestore
  void _loadPendingRequests() {
    _requestsSubscription = _firestore
        .collection("Requests")
        .where("Status", isEqualTo: "Pending")
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                pendingRequests = snapshot.docs.length;
              });
            }
          },
          onError: (error) {
            print("Error loading pending requests: $error");
          },
        );
  }

  // Load pending complaints count
  void _loadPendingComplaints() {
    _complaintsSubscription = _firestore
        .collection("Complaints")
        .where("status", isEqualTo: "Pending")
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                pendingComplaints = snapshot.docs.length;
              });
            }
          },
          onError: (error) {
            print("Error loading pending complaints: $error");
          },
        );
  }

  // Load total kilograms from all collections
  void _loadTotalKilograms() {
    _collectionsSubscription = _firestore
        .collection("Collections")
        .where("status", isEqualTo: "completed")
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              double total = 0.0;
              for (var doc in snapshot.docs) {
                var data = doc.data() as Map<String, dynamic>;
                double quantity = (data['quantity'] ?? 0).toDouble();
                total += quantity;
              }
              setState(() {
                totalKilograms = total;
              });
            }
          },
          onError: (error) {
            print("Error loading total kilograms: $error");
          },
        );
  }

  // Load today's kilograms
  void _loadTodayKilograms() {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);

    _todayCollectionsSubscription = _firestore
        .collection("Collections")
        .where("status", isEqualTo: "completed")
        .where("collectionDate", isGreaterThanOrEqualTo: startOfDay)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              double todayTotal = 0.0;
              int todayCount = 0;

              for (var doc in snapshot.docs) {
                var data = doc.data() as Map<String, dynamic>;
                double quantity = (data['quantity'] ?? 0).toDouble();
                todayTotal += quantity;
                todayCount++;
              }

              setState(() {
                todayKilograms = todayTotal;
                completedToday = todayCount;
              });
            }
          },
          onError: (error) {
            print("Error loading today's kilograms: $error");
          },
        );
  }

  // FIXED: Load active trucks count - now looks for "Active" status (capitalized)
  void _loadActiveTrucks() {
    _trucksSubscription = _firestore
        .collection("Trucks")
        .where(
          "status",
          isEqualTo: "Active",
        ) // Changed from "active" to "Active"
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                activeTrucks = snapshot.docs.length;
              });
            }
          },
          onError: (error) {
            print("Error loading active trucks: $error");
          },
        );
  }

  // Enhanced increment method that tracks kilograms
  void incrementCompletedCount(
    String requestId,
    Map<String, dynamic> requestData,
  ) {
    double quantity = (requestData['quantity'] ?? 0).toDouble();

    if (mounted) {
      setState(() {
        todayKilograms += quantity;
        totalKilograms += quantity;
        completedToday += 1;
        pendingRequests = pendingRequests > 0 ? pendingRequests - 1 : 0;
      });
    }
  }

  // Format kilograms for display
  String _formatKilograms(double kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(1)} tons';
    } else {
      return '${kg.toStringAsFixed(1)} kg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          // Complaints icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.report_problem),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ComplaintManagement(), // REMOVED const
                    ),
                  );
                },
                tooltip: 'View Complaints',
              ),
              if (pendingComplaints > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingComplaints > 99
                          ? '99+'
                          : pendingComplaints.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPendingRequests();
              _loadPendingComplaints();
              _loadTodayKilograms();
              _loadTotalKilograms();
              _loadActiveTrucks();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 40.0,
                bottom: 30.0,
                left: 20.0,
                right: 20.0,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[800]!, Colors.green[600]!],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Admin Dashboard",
                    style: TextStyle(
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    "Garbage Collection Management",
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 25.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        "Pending",
                        pendingRequests.toString(),
                        Icons.pending_actions,
                      ),
                      _buildStatCard(
                        "Today",
                        _formatKilograms(todayKilograms),
                        Icons.today,
                      ),
                      _buildStatCard(
                        "Active Trucks",
                        activeTrucks.toString(),
                        Icons.local_shipping,
                      ),
                      // Complaints stat card
                      _buildStatCard(
                        "Complaints",
                        pendingComplaints.toString(),
                        Icons.report_problem,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Management Tools",
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 15.0),

                  // Admin Approval Card
                  _buildManagementCard(
                    "Collection Approvals",
                    "$pendingRequests pending requests to review",
                    Icons.assignment_turned_in,
                    Colors.green[700]!,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => AdminApproval(
                                onRequestApproved: (
                                  String requestId,
                                  Map<String, dynamic> requestData,
                                ) {
                                  incrementCompletedCount(
                                    requestId,
                                    requestData,
                                  );
                                },
                              ),
                        ),
                      ).then((_) {
                        _loadPendingRequests();
                        _loadTodayKilograms();
                        _loadTotalKilograms();
                      });
                    },
                  ),
                  const SizedBox(height: 20.0),

                  // Complaints Management Card
                  _buildManagementCard(
                    "Truck Complaints",
                    "$pendingComplaints pending complaints to review",
                    Icons.report_problem,
                    Colors.orange[700]!,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ComplaintManagement(), // REMOVED const
                        ),
                      ).then((_) {
                        _loadPendingComplaints();
                      });
                    },
                  ),
                  const SizedBox(height: 20.0),

                  // Truck Management Card
                  _buildManagementCard(
                    "Truck Management",
                    "Monitor and manage garbage truck fleet",
                    Icons.local_shipping,
                    Colors.blue[700]!,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TruckManagement(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20.0),

                  // Collection Analytics Card
                  _buildManagementCard(
                    "Collection Analytics",
                    "View performance metrics and statistics",
                    Icons.analytics,
                    Colors.purple[700]!,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CollectionAnalytics(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20.0),

                  // Route Optimization Card
                  _buildManagementCard(
                    "Route Optimization",
                    "Plan and optimize collection routes",
                    Icons.map,
                    Colors.teal[700]!,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RouteOptimization(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom Summary Section
            Container(
              margin: const EdgeInsets.all(20.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Waste Collected",
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          Text(
                            "All time collection in kilograms",
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatKilograms(totalKilograms),
                        style: TextStyle(
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        "Today's Collection",
                        _formatKilograms(todayKilograms),
                        Icons.today,
                        Colors.blue[700]!,
                      ),
                      _buildMetricItem(
                        "Total Collections",
                        completedToday.toString(),
                        Icons.check_circle,
                        Colors.green[700]!,
                      ),
                      _buildMetricItem(
                        "Active Trucks",
                        activeTrucks.toString(),
                        Icons.local_shipping,
                        Colors.orange[700]!,
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

  // Stat Card Widget
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Metric item for additional statistics
  Widget _buildMetricItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Management Card Widget
  Widget _buildManagementCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.9), color],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
