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

  // Load active trucks count
  void _loadActiveTrucks() {
    _trucksSubscription = _firestore
        .collection("Trucks")
        .where("status", isEqualTo: "Active")
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

  // Refresh all data
  void _refreshData() {
    _loadPendingRequests();
    _loadPendingComplaints();
    _loadTodayKilograms();
    _loadTotalKilograms();
    _loadActiveTrucks();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final bool isSmallScreen = screenWidth < 360;
    final bool isLargeScreen = screenWidth > 600;

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
                      builder: (context) => ComplaintManagement(),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 8 : 10,
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
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  // Header Section
                  _buildHeaderSection(
                    screenWidth,
                    screenHeight,
                    isPortrait,
                    isSmallScreen,
                    isLargeScreen,
                  ),

                  // Main Content
                  _buildMainContent(
                    screenWidth,
                    screenHeight,
                    isPortrait,
                    isSmallScreen,
                    isLargeScreen,
                  ),

                  // Bottom Summary Section
                  _buildSummarySection(
                    screenWidth,
                    screenHeight,
                    isSmallScreen,
                    isLargeScreen,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Header Section Widget
  Widget _buildHeaderSection(
    double screenWidth,
    double screenHeight,
    bool isPortrait,
    bool isSmallScreen,
    bool isLargeScreen,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: screenHeight * (isLargeScreen ? 0.04 : 0.05),
        bottom: screenHeight * (isLargeScreen ? 0.03 : 0.04),
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
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
              fontSize:
                  isSmallScreen ? screenWidth * 0.07 : screenWidth * 0.065,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            "Garbage Collection Management",
            style: TextStyle(
              fontSize:
                  isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          _buildStatsGrid(
            screenWidth,
            screenHeight,
            isPortrait,
            isSmallScreen,
            isLargeScreen,
          ),
        ],
      ),
    );
  }

  // Stats Grid Widget
  Widget _buildStatsGrid(
    double screenWidth,
    double screenHeight,
    bool isPortrait,
    bool isSmallScreen,
    bool isLargeScreen,
  ) {
    if (!isPortrait || isLargeScreen) {
      // Landscape or large screen layout
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            "Pending",
            pendingRequests.toString(),
            Icons.pending_actions,
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          _buildStatCard(
            "Today",
            _formatKilograms(todayKilograms),
            Icons.today,
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          _buildStatCard(
            "Active Trucks",
            activeTrucks.toString(),
            Icons.local_shipping,
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          _buildStatCard(
            "Complaints",
            pendingComplaints.toString(),
            Icons.report_problem,
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
        ],
      );
    } else {
      // Portrait layout for small/medium screens
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatCard(
              "Pending",
              pendingRequests.toString(),
              Icons.pending_actions,
              screenWidth,
              screenHeight,
              isSmallScreen,
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _buildStatCard(
              "Today",
              _formatKilograms(todayKilograms),
              Icons.today,
              screenWidth,
              screenHeight,
              isSmallScreen,
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _buildStatCard(
              "Trucks",
              activeTrucks.toString(),
              Icons.local_shipping,
              screenWidth,
              screenHeight,
              isSmallScreen,
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: _buildStatCard(
              "Complaints",
              pendingComplaints.toString(),
              Icons.report_problem,
              screenWidth,
              screenHeight,
              isSmallScreen,
            ),
          ),
        ],
      );
    }
  }

  // Main Content Widget
  Widget _buildMainContent(
    double screenWidth,
    double screenHeight,
    bool isPortrait,
    bool isSmallScreen,
    bool isLargeScreen,
  ) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Management Tools",
            style: TextStyle(
              fontSize:
                  isSmallScreen ? screenWidth * 0.06 : screenWidth * 0.055,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          // Management Cards
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
                          incrementCompletedCount(requestId, requestData);
                        },
                      ),
                ),
              ).then((_) {
                _refreshData();
              });
            },
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),

          _buildManagementCard(
            "Truck Complaints",
            "$pendingComplaints pending complaints to review",
            Icons.report_problem,
            Colors.orange[700]!,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ComplaintManagement()),
              ).then((_) {
                _loadPendingComplaints();
              });
            },
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),

          _buildManagementCard(
            "Truck Management",
            "Monitor and manage garbage truck fleet",
            Icons.local_shipping,
            Colors.blue[700]!,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TruckManagement()),
              );
            },
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),

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
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),

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
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
        ],
      ),
    );
  }

  // Summary Section Widget
  Widget _buildSummarySection(
    double screenWidth,
    double screenHeight,
    bool isSmallScreen,
    bool isLargeScreen,
  ) {
    return Container(
      margin: EdgeInsets.all(screenWidth * 0.05),
      padding: EdgeInsets.all(screenWidth * 0.05),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Waste Collected",
                      style: TextStyle(
                        fontSize:
                            isSmallScreen
                                ? screenWidth * 0.045
                                : screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    Text(
                      "All time collection in kilograms",
                      style: TextStyle(
                        fontSize:
                            isSmallScreen
                                ? screenWidth * 0.03
                                : screenWidth * 0.035,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                _formatKilograms(totalKilograms),
                style: TextStyle(
                  fontSize:
                      isSmallScreen ? screenWidth * 0.055 : screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          _buildMetricsRow(screenWidth, screenHeight, isSmallScreen),
        ],
      ),
    );
  }

  // Metrics Row Widget
  Widget _buildMetricsRow(
    double screenWidth,
    double screenHeight,
    bool isSmallScreen,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetricItem(
          "Today's Collection",
          _formatKilograms(todayKilograms),
          Icons.today,
          Colors.blue[700]!,
          screenWidth,
          isSmallScreen,
        ),
        _buildMetricItem(
          "Total Collections",
          completedToday.toString(),
          Icons.check_circle,
          Colors.green[700]!,
          screenWidth,
          isSmallScreen,
        ),
        _buildMetricItem(
          "Active Trucks",
          activeTrucks.toString(),
          Icons.local_shipping,
          Colors.orange[700]!,
          screenWidth,
          isSmallScreen,
        ),
      ],
    );
  }

  // Stat Card Widget
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    double screenWidth,
    double screenHeight,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: isSmallScreen ? screenWidth * 0.06 : screenWidth * 0.07,
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            value,
            style: TextStyle(
              fontSize:
                  isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: TextStyle(
              fontSize:
                  isSmallScreen ? screenWidth * 0.025 : screenWidth * 0.03,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    double screenWidth,
    bool isSmallScreen,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: isSmallScreen ? screenWidth * 0.07 : screenWidth * 0.08,
        ),
        SizedBox(height: screenWidth * 0.02),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? screenWidth * 0.035 : screenWidth * 0.04,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: screenWidth * 0.01),
        Text(
          title,
          style: TextStyle(
            fontSize: isSmallScreen ? screenWidth * 0.025 : screenWidth * 0.03,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
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
    double screenWidth,
    double screenHeight,
    bool isSmallScreen,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
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
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Row(
            children: [
              Container(
                width: isSmallScreen ? screenWidth * 0.12 : screenWidth * 0.15,
                height: isSmallScreen ? screenWidth * 0.12 : screenWidth * 0.15,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isSmallScreen ? screenWidth * 0.06 : screenWidth * 0.07,
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize:
                            isSmallScreen
                                ? screenWidth * 0.045
                                : screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.005),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize:
                            isSmallScreen
                                ? screenWidth * 0.03
                                : screenWidth * 0.035,
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
                size: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
