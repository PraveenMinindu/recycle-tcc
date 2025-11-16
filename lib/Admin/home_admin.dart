// home_admin.dart - UPDATED WITH REWARDS MANAGEMENT
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:recycleapp/Admin/admin_approval.dart';
import 'package:recycleapp/Admin/truckmanagement.dart';
import 'package:recycleapp/Admin/collection_analytics.dart';
import 'package:recycleapp/Admin/route_optimization.dart';
import 'package:recycleapp/Admin/complaint_management.dart';
import 'package:recycleapp/Admin/admin_login.dart';
import 'package:recycleapp/Admin/news_events_management.dart';
import 'package:recycleapp/Admin/admin_rewards_management.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recycleapp/services/database.dart';

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
  bool _isMigrating = false;
  bool _isLoggingOut = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final DatabaseMethods _databaseMethods = DatabaseMethods();

  StreamSubscription? _requestsSubscription;
  StreamSubscription? _totalWasteSubscription;
  StreamSubscription? _trucksSubscription;
  StreamSubscription? _complaintsSubscription;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    _loadTotalWasteCollected();
    _loadActiveTrucks();
    _loadPendingComplaints();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _totalWasteSubscription?.cancel();
    _trucksSubscription?.cancel();
    _complaintsSubscription?.cancel();
    super.dispose();
  }

  // LOGOUT FUNCTIONALITY
  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Show confirmation dialog
      bool? confirmLogout = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Logout'),
                ),
              ],
            ),
      );

      if (confirmLogout != true) {
        setState(() {
          _isLoggingOut = false;
        });
        return;
      }

      // Sign out from Firebase
      await _auth.signOut();

      // Sign out from Google Sign-In if used
      await _googleSignIn.signOut();

      // Clear shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdminLoggedIn', false);
      await prefs.remove('adminIdentifier');

      // Navigate to login screen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminLogin()),
          (route) => false,
        );
      }
    } catch (e) {
      print("Error during logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  // ADD MIGRATION FUNCTION HERE
  Future<void> _migrateComplaints() async {
    if (_isMigrating) return;

    setState(() {
      _isMigrating = true;
    });

    try {
      // Show confirmation dialog
      bool? confirmMigration = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Migrate Complaints'),
              content: const Text(
                'This will migrate all existing complaints to the new unified system. This action cannot be undone. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Migrate'),
                ),
              ],
            ),
      );

      if (confirmMigration != true) {
        setState(() {
          _isMigrating = false;
        });
        return;
      }

      // Migrate UserComplaints to unified complaints collection
      final userComplaints =
          await _firestore.collection('UserComplaints').get();
      int migratedCount = 0;

      for (var doc in userComplaints.docs) {
        final data = doc.data();
        await _firestore.collection('complaints').add({
          'userId': data['userId'] ?? doc.id,
          'userEmail': data['userEmail'] ?? 'unknown@email.com',
          'userName': data['userName'] ?? 'User',
          'type': 'user',
          'category': data['category'] ?? 'Other',
          'details': data['details'] ?? 'No details',
          'status': (data['status'] ?? 'Pending').toLowerCase(),
          'priority': data['priority'] ?? 'medium',
          'imageUrls': data['imageUrls'] ?? [],
          'location': data['location'] ?? 'Not specified',
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'assignedTo': null,
          'adminNotes': data['adminNotes'],
          'migrated': true,
        });
        migratedCount++;
      }

      // Migrate old Complaints collection (driver complaints)
      final driverComplaints = await _firestore.collection('Complaints').get();

      for (var doc in driverComplaints.docs) {
        final data = doc.data();
        await _firestore.collection('complaints').add({
          'userId': data['userId'] ?? doc.id,
          'userEmail': data['userEmail'] ?? 'driver@email.com',
          'type': 'driver',
          'title': data['title'] ?? 'Driver Complaint',
          'description':
              data['description'] ?? data['details'] ?? 'No description',
          'driverName': data['driverName'] ?? 'Unknown Driver',
          'truckLicensePlate': data['truckLicensePlate'] ?? 'Unknown',
          'category': data['category'] ?? 'Truck',
          'priority': data['priority'] ?? 'medium',
          'location': data['location'] ?? 'Not specified',
          'status': (data['status'] ?? 'Pending').toLowerCase(),
          'imageUrls': data['imageUrls'] ?? [],
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'assignedTo': null,
          'adminNotes': data['adminNotes'],
          'migrated': true,
        });
        migratedCount++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully migrated $migratedCount complaints!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Refresh complaints data after migration
      _loadPendingComplaints();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Migration failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
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

  // UPDATED: Load total waste collected from TotalCollections (combines both sources)
  void _loadTotalWasteCollected() {
    _totalWasteSubscription = _databaseMethods.getTotalWasteStream().listen(
      (snapshot) {
        if (mounted && snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final todayWeight = (data['totalWeight'] ?? 0).toDouble();
          final todayCollections = (data['totalCollections'] ?? 0) as int;

          setState(() {
            todayKilograms = todayWeight;
            completedToday = todayCollections;
          });

          // Also load all-time total
          _loadAllTimeTotal();
        }
      },
      onError: (error) {
        print("Error loading total waste: $error");
        // Fallback to old method if new one fails
        _loadTotalWasteFallback();
      },
    );
  }

  // Fallback method for total waste calculation
  void _loadTotalWasteFallback() {
    _totalWasteSubscription = _firestore
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

  // Load all-time total waste
  void _loadAllTimeTotal() async {
    try {
      final allTimeData = await _databaseMethods.getAllTimeTotalWaste();
      if (mounted) {
        setState(() {
          totalKilograms = allTimeData['allTimeWeight'] ?? 0.0;
        });
      }
    } catch (e) {
      print("Error loading all-time total: $e");
    }
  }

  // UPDATED: Load pending complaints count from new unified system
  void _loadPendingComplaints() {
    _complaintsSubscription = _firestore
        .collection("complaints")
        .where("status", isEqualTo: "pending")
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
            // Fallback to old collection if new one doesn't exist
            _loadPendingComplaintsFallback();
          },
        );
  }

  // Fallback method for old complaints collection
  void _loadPendingComplaintsFallback() {
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
            print("Error loading fallback complaints: $error");
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
    _loadTotalWasteCollected();
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
          // Logout Button
          if (_isLoggingOut)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),

          // Migration button (temporary - you can remove after migration)
          if (!_isMigrating)
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings),
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'migrate',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          const Text('Migrate Complaints'),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'migrate') {
                  _migrateComplaints();
                }
              },
            ),
          // Complaints icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.report_problem),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ComplaintManagement(),
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
            icon:
                _isMigrating
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(Icons.refresh),
            onPressed: _isMigrating ? null : _refreshData,
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

                  // UPDATED: Total Waste Collection Section
                  _buildTotalWasteSection(
                    screenWidth,
                    screenHeight,
                    isSmallScreen,
                    isLargeScreen,
                  ),

                  // Migration Status Banner (temporary)
                  if (_isMigrating) _buildMigrationBanner(screenWidth),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // NEW: Total Waste Collection Section Widget
  Widget _buildTotalWasteSection(
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
          // Header with Live indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Total Waste Collected Today",
                          style: TextStyle(
                            fontSize:
                                isSmallScreen
                                    ? screenWidth * 0.045
                                    : screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        StreamBuilder<DocumentSnapshot>(
                          stream: _databaseMethods.getTotalWasteStream(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Row(
                                children: [
                                  Icon(
                                    Icons.live_tv,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "LIVE",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return SizedBox();
                          },
                        ),
                      ],
                    ),
                    Text(
                      "Combined from User Submissions & Driver Collections",
                      style: TextStyle(
                        fontSize:
                            isSmallScreen
                                ? screenWidth * 0.03
                                : screenWidth * 0.035,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),

          // Today's Collection Stats
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade50, Colors.blue.shade50],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWasteMetric(
                  "Today's Weight",
                  _formatKilograms(todayKilograms),
                  Icons.scale,
                  Colors.green[700]!,
                  screenWidth,
                  isSmallScreen,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.withOpacity(0.3),
                ),
                _buildWasteMetric(
                  "Today's Collections",
                  completedToday.toString(),
                  Icons.recycling,
                  Colors.blue[700]!,
                  screenWidth,
                  isSmallScreen,
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),

          // All Time Total
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.orange[700], size: 24),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "All Time Total",
                        style: TextStyle(
                          fontSize:
                              isSmallScreen
                                  ? screenWidth * 0.035
                                  : screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      Text(
                        _formatKilograms(totalKilograms),
                        style: TextStyle(
                          fontSize:
                              isSmallScreen
                                  ? screenWidth * 0.045
                                  : screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
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
    );
  }

  // NEW: Waste Metric Widget
  Widget _buildWasteMetric(
    String title,
    String value,
    IconData icon,
    Color color,
    double screenWidth,
    bool isSmallScreen,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 24 : 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? screenWidth * 0.04 : screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: isSmallScreen ? screenWidth * 0.025 : screenWidth * 0.03,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Migration Banner Widget
  Widget _buildMigrationBanner(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      color: Colors.orange[50],
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Text(
              'Migrating complaints to new system...',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
            "Complaint Management",
            "$pendingComplaints pending complaints to review",
            Icons.report_problem,
            Colors.orange[700]!,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ComplaintManagement(),
                ),
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
          SizedBox(height: screenHeight * 0.02),

          // News & Events Management Card
          _buildManagementCard(
            "News & Events",
            "Manage news articles and events",
            Icons.article,
            Colors.pink[700]!,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewsEventsManagement(),
                ),
              );
            },
            screenWidth,
            screenHeight,
            isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),

          // NEW: Rewards Management Card
          _buildManagementCard(
            "Rewards Management",
            "Manage discounts, offers and user rewards",
            Icons.card_giftcard,
            Colors.deepPurple[700]!,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminRewardsManagement(),
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
