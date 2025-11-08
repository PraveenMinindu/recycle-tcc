import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class TruckManagement extends StatefulWidget {
  const TruckManagement({super.key});

  @override
  State<TruckManagement> createState() => _TruckManagementState();
}

class _TruckManagementState extends State<TruckManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _trucksSubscription;
  StreamSubscription? _truckRequestsSubscription;

  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _truckRequests = [];
  bool _isLoading = true;

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Active',
    'Maintenance',
    'Available',
  ];

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTrucks();
    _loadTruckRequests();
  }

  @override
  void dispose() {
    _trucksSubscription?.cancel();
    _truckRequestsSubscription?.cancel();
    super.dispose();
  }

  void _loadTrucks() {
    _trucksSubscription = _firestore
        .collection("Trucks")
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _trucks =
                    snapshot.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        'id': doc.id,
                        'licensePlate': data['licensePlate'] ?? 'Unknown',
                        'capacity': data['capacity'] ?? '0 kg',
                        'status': data['status'] ?? 'Available',
                        'currentLocation':
                            data['currentLocation'] ?? 'Not specified',
                        'assignedDriver':
                            data['assignedDriver'] ?? 'Not assigned',
                        'driverId': data['driverId'] ?? '',
                        'lastMaintenance': data['lastMaintenance'] ?? 'Not set',
                        'nextMaintenance': data['nextMaintenance'] ?? 'Not set',
                        'truckType': data['truckType'] ?? 'Not specified',
                      };
                    }).toList();
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print("Error loading trucks: $error");
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        );
  }

  void _loadTruckRequests() {
    _truckRequestsSubscription = _firestore
        .collection("TruckAssignmentRequests")
        .where("requestStatus", isEqualTo: "Pending")
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _truckRequests =
                  snapshot.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {'id': doc.id, ...data};
                  }).toList();
            });
          }
        });
  }

  Future<void> _approveTruckRequest(Map<String, dynamic> request) async {
    try {
      // Update the truck with driver assignment
      await _firestore.collection("Trucks").doc(request['truckId']).update({
        'assignedDriver': request['driverName'],
        'driverId': request['driverId'],
        'status': 'Available', // Set to Available initially
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the request status
      await _firestore
          .collection("TruckAssignmentRequests")
          .doc(request['id'])
          .update({
            'requestStatus': 'Approved',
            'approvedDate': FieldValue.serverTimestamp(),
            'approvedBy': 'admin',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Truck ${request['licensePlate']} assigned to ${request['driverName']} successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving truck assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectTruckRequest(
    String requestId,
    String licensePlate,
    String driverName,
  ) async {
    try {
      await _firestore
          .collection("TruckAssignmentRequests")
          .doc(requestId)
          .update({
            'requestStatus': 'Rejected',
            'rejectedDate': FieldValue.serverTimestamp(),
            'rejectedBy': 'admin',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Truck assignment for $driverName rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add new truck functionality for admin
  void _showAddTruckDialog() {
    final licensePlateController = TextEditingController();
    final capacityController = TextEditingController();
    String selectedTruckType = 'Small Truck (1-2 tons)';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Add New Truck',
            style: TextStyle(color: Colors.green[800]),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: licensePlateController,
                  decoration: InputDecoration(
                    labelText: 'License Plate *',
                    hintText: 'e.g., ABC-123',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: capacityController,
                  decoration: InputDecoration(
                    labelText: 'Capacity (kg) *',
                    hintText: 'e.g., 5000',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedTruckType,
                  decoration: InputDecoration(
                    labelText: 'Truck Type *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                        'Small Truck (1-2 tons)',
                        'Medium Truck (3-5 tons)',
                        'Large Truck (6-10 tons)',
                        'Container Truck (10+ tons)',
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedTruckType = value!;
                    });
                  },
                ),
                SizedBox(height: 15),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    hintText: 'Any special features or requirements',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (licensePlateController.text.isNotEmpty &&
                    capacityController.text.isNotEmpty) {
                  await _addNewTruck(
                    licensePlateController.text,
                    capacityController.text,
                    selectedTruckType,
                    notesController.text,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
              ),
              child: Text('Add Truck', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addNewTruck(
    String licensePlate,
    String capacity,
    String truckType,
    String notes,
  ) async {
    try {
      final newTruck = {
        'licensePlate': licensePlate,
        'capacity': '$capacity kg',
        'truckType': truckType,
        'status': 'Available',
        'currentLocation': 'Not specified',
        'assignedDriver': 'Not assigned',
        'driverId': '',
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
        'lastMaintenance': 'Not set',
        'nextMaintenance': 'Not set',
      };

      await _firestore.collection("Trucks").add(newTruck);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Truck $licensePlate added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding truck: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.green[700]),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTruckCard(Map<String, dynamic> truck) {
    Color statusColor;
    switch (truck['status']) {
      case 'Active':
        statusColor = Colors.green;
        break;
      case 'Maintenance':
        statusColor = Colors.orange;
        break;
      case 'Available':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    truck['licensePlate'],
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
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
                    truck['status'],
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTruckInfoRow('Capacity', truck['capacity'], Icons.inventory),
            _buildTruckInfoRow(
              'Truck Type',
              truck['truckType'],
              Icons.local_shipping,
            ),
            _buildTruckInfoRow(
              'Current Location',
              truck['currentLocation'],
              Icons.location_on,
            ),
            _buildTruckInfoRow('Driver', truck['assignedDriver'], Icons.person),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Last Maintenance: ${truck['lastMaintenance']}',
                    style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _showDeleteDialog(truck),
                  icon: Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTruckInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';

    if (date is Timestamp) {
      DateTime dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (date is String) {
      return date;
    } else {
      return 'Invalid date';
    }
  }

  void _showRejectDialog(
    String requestId,
    String licensePlate,
    String driverName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reject Assignment Request'),
          content: Text(
            'Are you sure you want to reject $driverName\'s request for truck $licensePlate?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectTruckRequest(requestId, licensePlate, driverName);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(Map<String, dynamic> truck) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Truck'),
          content: Text(
            'Are you sure you want to delete truck ${truck['licensePlate']}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTruck(truck);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTruck(Map<String, dynamic> truck) async {
    try {
      await _firestore.collection("Trucks").doc(truck['id']).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Truck ${truck['licensePlate']} deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting truck: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTrucks =
        _selectedFilter == 'All'
            ? _trucks
            : _trucks
                .where((truck) => truck['status'] == _selectedFilter)
                .toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Truck Management',
          style: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.green[800]),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_truckRequests.isNotEmpty)
            Badge(
              label: Text(_truckRequests.length.toString()),
              backgroundColor: Colors.red,
              child: IconButton(
                icon: Icon(Icons.pending_actions, color: Colors.green[800]),
                onPressed: () {
                  setState(() {
                    _currentTabIndex = 1;
                  });
                },
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.green[700]),
              )
              : Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: Row(
                      children: [
                        _buildTabButton('Trucks', 0),
                        _buildTabButton(
                          'Pending Requests',
                          1,
                          _truckRequests.length,
                        ),
                      ],
                    ),
                  ),

                  if (_currentTabIndex == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter:',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children:
                                  _filterOptions.map((filter) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8.0),
                                      child: FilterChip(
                                        label: Text(filter),
                                        selected: _selectedFilter == filter,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedFilter =
                                                selected ? filter : 'All';
                                          });
                                        },
                                        backgroundColor: Colors.grey[200],
                                        selectedColor: Colors.green[300],
                                        labelStyle: TextStyle(
                                          color:
                                              _selectedFilter == filter
                                                  ? Colors.white
                                                  : Colors.green[800],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // FIXED: Added "Available" stat item
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.green[50],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total Trucks',
                            _trucks.length.toString(),
                            Icons.local_shipping,
                          ),
                          _buildStatItem(
                            'Active',
                            _trucks
                                .where((t) => t['status'] == 'Active')
                                .length
                                .toString(),
                            Icons.check_circle,
                          ),
                          _buildStatItem(
                            'Available',
                            _trucks
                                .where((t) => t['status'] == 'Available')
                                .length
                                .toString(),
                            Icons.local_shipping,
                          ),
                          _buildStatItem(
                            'Maintenance',
                            _trucks
                                .where((t) => t['status'] == 'Maintenance')
                                .length
                                .toString(),
                            Icons.build,
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child:
                          filteredTrucks.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_shipping,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No trucks found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      _selectedFilter == 'All'
                                          ? 'Add trucks using the + button below'
                                          : 'No trucks with status: $_selectedFilter',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: filteredTrucks.length,
                                itemBuilder: (context, index) {
                                  final truck = filteredTrucks[index];
                                  return _buildTruckCard(truck);
                                },
                              ),
                    ),
                  ] else ...[
                    _buildTruckRequestsTab(),
                  ],
                ],
              ),
      floatingActionButton:
          _currentTabIndex == 0
              ? FloatingActionButton(
                onPressed: _showAddTruckDialog,
                backgroundColor: Colors.green[700],
                child: Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }

  Widget _buildTabButton(String title, int tabIndex, [int badgeCount = 0]) {
    bool isSelected = _currentTabIndex == tabIndex;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8.0),
        height: 50, // Fixed height for both buttons
        child: Stack(
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentTabIndex = tabIndex;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSelected ? Colors.green[700] : Colors.grey[200],
                foregroundColor: isSelected ? Colors.white : Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(
                  double.infinity,
                  50,
                ), // Same minimum size
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTruckRequestsTab() {
    return Expanded(
      child:
          _truckRequests.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Pending Requests',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    Text(
                      'All truck assignment requests have been processed',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _truckRequests.length,
                itemBuilder: (context, index) {
                  final request = _truckRequests[index];
                  return _buildTruckRequestCard(request);
                },
              ),
    );
  }

  Widget _buildTruckRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['licensePlate'],
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Driver: ${request['driverName']}',
                        style: TextStyle(
                          fontSize: 14.0,
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    'Assignment Pending',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequestInfoRow('Driver', request['driverName'], Icons.person),
            _buildRequestInfoRow(
              'Capacity',
              request['capacity'],
              Icons.inventory,
            ),
            _buildRequestInfoRow(
              'Truck Type',
              request['truckType'],
              Icons.local_shipping,
            ),
            _buildRequestInfoRow('Driver ID', request['driverId'], Icons.badge),

            _buildRequestInfoRow(
              'Request Date',
              _formatDate(request['requestDate']),
              Icons.calendar_today,
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveTruckRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Approve Assignment',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        () => _showRejectDialog(
                          request['id'],
                          request['licensePlate'],
                          request['driverName'],
                        ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
