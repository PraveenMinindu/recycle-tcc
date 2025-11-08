import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'dart:async';

class TruckDriverApp extends StatefulWidget {
  const TruckDriverApp({super.key});

  @override
  State<TruckDriverApp> createState() => _TruckDriverAppState();
}

class _TruckDriverAppState extends State<TruckDriverApp> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _driverId;
  String? _driverName;
  Map<String, dynamic>? _assignedTruck;
  bool _isLoading = true;

  // Define available status options for drivers
  final List<Map<String, dynamic>> _statusOptions = [
    {
      'value': 'Available',
      'label': 'Available',
      'description': 'Ready for new collection tasks',
      'color': Colors.blue,
      'icon': Icons.check_circle,
    },
    {
      'value': 'Active',
      'label': 'On Duty',
      'description': 'Currently collecting garbage',
      'color': Colors.green,
      'icon': Icons.directions_car,
    },
    {
      'value': 'Maintenance',
      'label': 'Maintenance',
      'description': 'Truck under maintenance',
      'color': Colors.orange,
      'icon': Icons.build,
    },
  ];

  StreamSubscription? _truckSubscription;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    _truckSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    _driverId = await SharedpreferenceHelper().getUserId();
    _driverName = await SharedpreferenceHelper().getUserName();

    if (_driverId != null) {
      _loadAssignedTruck();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _loadAssignedTruck() {
    _truckSubscription = _firestore
        .collection("Trucks")
        .where("driverId", isEqualTo: _driverId)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                if (snapshot.docs.isNotEmpty) {
                  final doc = snapshot.docs.first;
                  final data = doc.data() as Map<String, dynamic>;

                  // **FIX: Validate required fields**
                  if (data['licensePlate'] != null) {
                    _assignedTruck = {'id': doc.id, ...data};
                  } else {
                    print("Invalid truck data: missing required fields");
                    _assignedTruck = null;
                  }
                } else {
                  _assignedTruck = null;
                }
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print("Error loading assigned truck: $error");
            if (mounted) {
              setState(() {
                _assignedTruck = null;
                _isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _updateTruckStatus(String newStatus) async {
    if (_assignedTruck == null) return;

    try {
      // Update truck status
      await _firestore.collection("Trucks").doc(_assignedTruck!['id']).update({
        'status': newStatus,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add status change to history
      await _firestore.collection("TruckStatusHistory").add({
        'truckId': _assignedTruck!['id'],
        'licensePlate': _assignedTruck!['licensePlate'] ?? 'Unknown',
        'driverId': _driverId,
        'driverName': _driverName,
        'previousStatus': _assignedTruck!['status'] ?? 'Unknown',
        'newStatus': newStatus,
        'changedAt': FieldValue.serverTimestamp(),
        'changedBy': 'driver',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTruckLocation(String newLocation) async {
    if (_assignedTruck == null) return;

    try {
      await _firestore.collection("Trucks").doc(_assignedTruck!['id']).update({
        'currentLocation': newLocation,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated to: $newLocation'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // **FIXED: _leaveTruck method with null safety**
  Future<void> _leaveTruck() async {
    // **FIX: Add proper null safety check**
    if (_assignedTruck == null || _assignedTruck!['id'] == null) {
      print("No valid truck assigned to leave");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No truck assigned to leave")),
      );
      return;
    }

    try {
      // **FIX: Safe access to truck data**
      String truckId = _assignedTruck!['id'] ?? '';
      String licensePlate = _assignedTruck!['licensePlate'] ?? 'Unknown';
      String currentStatus = _assignedTruck!['status'] ?? 'Available';

      if (truckId.isEmpty) {
        throw Exception("Invalid truck ID");
      }

      // **FIX: Record truck assignment history with safe data access**
      await _firestore.collection("TruckAssignmentHistory").add({
        'truckId': truckId,
        'licensePlate': licensePlate,
        'driverId': _driverId,
        'driverName': _driverName,
        'assignedAt':
            _assignedTruck!['assignedAt'] ?? FieldValue.serverTimestamp(),
        'unassignedAt': FieldValue.serverTimestamp(),
        'lastStatus': currentStatus,
        'action': 'driver_left',
      });

      // **FIX: Update truck to remove driver assignment**
      await _firestore.collection("Trucks").doc(truckId).update({
        'driverId': '',
        'driverName': '',
        'status': 'Available',
        'currentLocation': 'Not assigned',
        'lastDriver': _driverName,
        'lastDriverId': _driverId,
        'unassignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // **FIX: Add status change to history**
      await _firestore.collection("TruckStatusHistory").add({
        'truckId': truckId,
        'licensePlate': licensePlate,
        'driverId': _driverId,
        'driverName': _driverName,
        'previousStatus': currentStatus,
        'newStatus': 'Available',
        'changedAt': FieldValue.serverTimestamp(),
        'changedBy': 'driver',
        'notes': 'Driver left the truck',
      });

      // **FIX: Show success message with safe data access**
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully left truck $licensePlate'),
          backgroundColor: Colors.green,
        ),
      );

      // **FIX: Clear local state BEFORE navigation**
      if (mounted) {
        setState(() {
          _assignedTruck = null;
        });
      }

      // **FIX: Wait a moment for state update, then navigate back**
      await Future.delayed(const Duration(milliseconds: 500));

      // **FIX: Safe navigation back**
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error leaving truck: $e");

      // **FIX: Better error message**
      String errorMessage = "Error leaving truck: ";
      if (e.toString().contains('Null check')) {
        errorMessage += "Truck data is invalid. Please refresh and try again.";
      } else {
        errorMessage += e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  void _showLocationUpdateDialog() {
    final locationController = TextEditingController(
      text: _assignedTruck?['currentLocation'] ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Current Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Update your current location for better tracking:'),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Current Location',
                  hintText: 'e.g., Downtown Area, Sector 15, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (locationController.text.isNotEmpty) {
                  _updateTruckLocation(locationController.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Update Location',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // **FIXED: _showLeaveTruckDialog method with null safety**
  void _showLeaveTruckDialog() {
    // **FIX: Add null safety check**
    if (_assignedTruck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No truck assigned to leave")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Truck'),
          content: Text(
            'Are you sure you want to leave truck ${_assignedTruck?['licensePlate'] ?? 'this truck'}? '
            'This will unassign you from the truck and it will be available for other drivers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Close the dialog first
                Navigator.pop(context);

                // Show loading indicator
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
                            const Text("Leaving truck..."),
                          ],
                        ),
                      ),
                    );
                  },
                );

                // Perform the leave truck operation
                await _leaveTruck();

                // **FIX: Close the loading dialog**
                if (mounted) {
                  Navigator.pop(context); // Close loading dialog
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text(
                'Leave Truck',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Big status buttons similar to quick action buttons
  Widget _buildBigStatusButton(Map<String, dynamic> statusOption) {
    bool isCurrentStatus = _assignedTruck?['status'] == statusOption['value'];
    Color color = statusOption['color'];
    IconData icon = statusOption['icon'];
    String label = statusOption['label'];

    return SizedBox(
      width: 100,
      child: ElevatedButton(
        onPressed: () => _updateTruckStatus(statusOption['value']),
        style: ElevatedButton.styleFrom(
          backgroundColor: isCurrentStatus ? color : Colors.grey[300],
          foregroundColor: isCurrentStatus ? Colors.white : Colors.grey[700],
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (isCurrentStatus) const SizedBox(height: 4),
            if (isCurrentStatus)
              const Icon(Icons.check, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildTruckInfo() {
    if (_assignedTruck == null) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No Truck Assigned",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please contact admin to assign you a truck",
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    Color statusColor;
    switch (_assignedTruck!['status']) {
      case 'Active':
        statusColor = Colors.green;
      case 'Maintenance':
        statusColor = Colors.orange;
      case 'Available':
        statusColor = Colors.blue;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with License Plate and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _assignedTruck!['licensePlate'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Assigned to: $_driverName',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          _assignedTruck!['status'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Truck Details
                  _buildDetailRow(
                    'Capacity',
                    _assignedTruck!['capacity'] ?? 'Not specified',
                    Icons.inventory,
                  ),
                  _buildDetailRow(
                    'Current Location',
                    _assignedTruck!['currentLocation'] ?? 'Not specified',
                    Icons.location_on,
                  ),
                  _buildDetailRow(
                    'Truck Type',
                    _assignedTruck!['truckType'] ?? 'Not specified',
                    Icons.local_shipping,
                  ),

                  // Action Buttons
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showLocationUpdateDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, size: 18),
                              const SizedBox(width: 8),
                              Text('Update Location'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showLeaveTruckDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.exit_to_app, size: 18),
                              const SizedBox(width: 8),
                              Text('Leave Truck'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status Update Section
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Colors.green[700], size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Update Truck Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select your current truck status:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),

                  // Big status buttons in a Wrap
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceEvenly,
                    children:
                        _statusOptions
                            .map((status) => _buildBigStatusButton(status))
                            .toList(),
                  ),

                  const SizedBox(height: 16),

                  // Status Descriptions
                  ..._statusOptions.map(
                    (status) => _buildStatusDescription(
                      status['label'],
                      status['description'],
                      status['color'],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: _showLocationUpdateDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            foregroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.location_on, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                'Update\nLocation',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: _showDriverTruckHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[50],
                            foregroundColor: Colors.green[700],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.history, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                'My Truck\nHistory',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: _showStatusHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[50],
                            foregroundColor: Colors.purple[700],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.timeline, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                'Status\nHistory',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverTruckHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('My Truck History'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<QuerySnapshot>(
              future: _getTruckAssignmentHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.green[700]),
                        const SizedBox(height: 16),
                        const Text('Loading truck history...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print("Error loading truck history: ${snapshot.error}");
                  return _buildNoHistoryWidget(
                    'No Truck History',
                    'You haven\'t used any trucks yet. Your truck assignment history will appear here when you leave a truck.',
                    Icons.history,
                    Colors.grey[400]!,
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNoHistoryWidget(
                    'No Truck History',
                    'You haven\'t used any trucks yet. Your truck assignment history will appear here when you leave a truck.',
                    Icons.history,
                    Colors.grey[400]!,
                  );
                }

                final historyData = snapshot.data!.docs;

                return Container(
                  height: 400,
                  child: ListView.builder(
                    itemCount: historyData.length,
                    itemBuilder: (context, index) {
                      final doc = historyData[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.local_shipping,
                            color: Colors.green[700],
                          ),
                          title: Text(
                            data['licensePlate'] ?? 'Unknown Truck',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned: ${_formatDate(data['assignedAt'])}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Left: ${_formatDate(data['unassignedAt'])}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Last Status: ${data['lastStatus'] ?? 'Unknown'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (data['action'] != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Action: ${data['action']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.history,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<QuerySnapshot> _getTruckAssignmentHistory() async {
    try {
      return await _firestore
          .collection("TruckAssignmentHistory")
          .where("driverId", isEqualTo: _driverId)
          .orderBy("unassignedAt", descending: true)
          .get();
    } catch (e) {
      print("Error fetching truck assignment history: $e");
      // Return empty list by using a different approach
      return await _firestore.collection("Trucks").limit(0).get();
    }
  }

  Future<QuerySnapshot> _getTruckStatusHistory() async {
    if (_assignedTruck == null) {
      return await _firestore.collection("Trucks").limit(0).get();
    }

    try {
      return await _firestore
          .collection("TruckStatusHistory")
          .where("truckId", isEqualTo: _assignedTruck!['id'])
          .orderBy("changedAt", descending: true)
          .get();
    } catch (e) {
      print("Error fetching truck status history: $e");
      // Return empty list by using a different approach
      return await _firestore.collection("Trucks").limit(0).get();
    }
  }

  Widget _buildNoHistoryWidget(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showStatusHistory() {
    if (_assignedTruck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No truck assigned to view status history'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Status History - ${_assignedTruck!['licensePlate'] ?? 'Unknown'}',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<QuerySnapshot>(
              future: _getTruckStatusHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.green[700]),
                        const SizedBox(height: 16),
                        const Text('Loading status history...'),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print("Error loading status history: ${snapshot.error}");
                  return _buildNoHistoryWidget(
                    'No Status History',
                    'Status changes will appear here when you update the truck status.',
                    Icons.timeline,
                    Colors.grey[400]!,
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNoHistoryWidget(
                    'No Status History',
                    'Status changes will appear here when you update the truck status.',
                    Icons.timeline,
                    Colors.grey[400]!,
                  );
                }

                return Container(
                  height: 400,
                  child: ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      Color statusColor = Colors.grey;
                      switch (data['newStatus']) {
                        case 'Active':
                          statusColor = Colors.green;
                          break;
                        case 'Available':
                          statusColor = Colors.blue;
                          break;
                        case 'Maintenance':
                          statusColor = Colors.orange;
                          break;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            '${data['previousStatus'] ?? 'Unknown'} → ${data['newStatus'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Changed by: ${data['changedBy'] ?? 'Unknown'}',
                              ),
                              Text('Date: ${_formatDate(data['changedAt'])}'),
                              if (data['notes'] != null)
                                Text('Notes: ${data['notes']}'),
                            ],
                          ),
                          trailing: Icon(Icons.swap_horiz, color: statusColor),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';

    if (date is Timestamp) {
      DateTime dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (date is String) {
      return date;
    } else {
      return 'Invalid date';
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDescription(
    String status,
    String description,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Truck Driver Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDriverData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green[700]),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading your truck information...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver Info Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.green[700]!, Colors.green[500]!],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          _driverName ?? 'Driver',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _assignedTruck != null
                              ? 'Assigned Truck: ${_assignedTruck!['licensePlate'] ?? 'Unknown'}'
                              : 'No truck assigned',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        if (_assignedTruck != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Current Status: ${_assignedTruck!['status'] ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Truck Information and Status Controls
                  Expanded(
                    child: SingleChildScrollView(child: _buildTruckInfo()),
                  ),
                ],
              ),
    );
  }
}
