// route_optimization.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // Add this import for StreamSubscription

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  final MapController _mapController = MapController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _binNameController = TextEditingController();

  List<Map<String, dynamic>> _allTrucks = [];
  List<BinLocation> _bins = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  bool _isAddingBin = false;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _trucksStreamSubscription;
  StreamSubscription<QuerySnapshot>? _binsStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadAllTrucks();
    _loadBinsFromFirestore();
  }

  @override
  void dispose() {
    _trucksStreamSubscription?.cancel();
    _binsStreamSubscription?.cancel();
    _binNameController.dispose();
    super.dispose();
  }

  void _loadAllTrucks() {
    _trucksStreamSubscription = _firestore
        .collection("Trucks")
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _allTrucks =
                    snapshot.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      // Get truck position - use real GPS data if available, otherwise use default
                      double lat =
                          data['currentLat'] ??
                          _getDefaultLat(data['licensePlate'] ?? 'Unknown');
                      double lng =
                          data['currentLng'] ??
                          _getDefaultLng(data['licensePlate'] ?? 'Unknown');

                      return {
                        'id': doc.id,
                        ...data,
                        'currentLat': lat,
                        'currentLng': lng,
                        'lastUpdate':
                            data['locationUpdatedAt'] ?? data['updatedAt'],
                      };
                    }).toList();
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print("Error loading trucks: $error");
            setState(() => _isLoading = false);
          },
        );
  }

  // Load bins from Firestore
  void _loadBinsFromFirestore() {
    _binsStreamSubscription = _firestore
        .collection("Bins")
        .snapshots()
        .listen(
          (QuerySnapshot snapshot) {
            if (mounted) {
              setState(() {
                _bins.clear();
                for (var doc in snapshot.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  _bins.add(
                    BinLocation(
                      data['name'] ?? 'Unknown Bin',
                      LatLng(data['latitude'], data['longitude']),
                      id: doc.id,
                    ),
                  );
                }
              });
            }
          },
          onError: (error) {
            print("Error loading bins: $error");
          },
        );
  }

  // Add bin to Firestore
  Future<void> _addBinToFirestore(String name, LatLng position) async {
    try {
      await _firestore.collection("Bins").add({
        'name': name,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'Admin', // You can replace with actual admin name/id
      });
    } catch (e) {
      print("Error adding bin to Firestore: $e");
      throw e;
    }
  }

  // Delete bin from Firestore
  Future<void> _deleteBinFromFirestore(String binId) async {
    try {
      await _firestore.collection("Bins").doc(binId).delete();
    } catch (e) {
      print("Error deleting bin from Firestore: $e");
      throw e;
    }
  }

  // Default positions for demo (centered around Sri Lanka)
  double _getDefaultLat(String licensePlate) {
    // Generate somewhat unique positions based on license plate
    int hash = licensePlate.hashCode;
    return 6.9271 + ((hash % 100) - 50) * 0.01; // Base: Colombo
  }

  double _getDefaultLng(String licensePlate) {
    int hash = licensePlate.hashCode;
    return 79.8612 + ((hash % 100) - 50) * 0.01; // Base: Colombo
  }

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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Active':
        return Icons.directions_car;
      case 'Maintenance':
        return Icons.build;
      case 'Available':
        return Icons.local_shipping;
      default:
        return Icons.help;
    }
  }

  void _toggleAddBinMode() {
    setState(() {
      _isAddingBin = !_isAddingBin;
    });
    if (_isAddingBin) {
      _showInfo('Tap anywhere on map to add bin');
    }
  }

  void _showAddBinDialog(LatLng position) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Bin'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _binNameController,
                  decoration: const InputDecoration(
                    labelText: 'Bin Name',
                    hintText: 'e.g., Bin 1, Main Street Bin',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 15),
                Text(
                  'Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_binNameController.text.trim().isEmpty) {
                    _showError('Please enter bin name');
                    return;
                  }

                  try {
                    await _addBinToFirestore(
                      _binNameController.text.trim(),
                      position,
                    );

                    _binNameController.clear();
                    Navigator.pop(context);
                    _showSuccess('Bin added successfully!');
                    setState(() => _isAddingBin = false);
                  } catch (e) {
                    _showError('Failed to add bin: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                ),
                child: const Text(
                  'Add Bin',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showDeleteBinConfirmation(BinLocation bin) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Bin'),
            content: Text('Are you sure you want to delete "${bin.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    if (bin.id != null) {
                      await _deleteBinFromFirestore(bin.id!);
                      Navigator.pop(context);
                      _showSuccess('Bin "${bin.name}" deleted successfully!');
                    } else {
                      _showError('Cannot delete bin: No ID found');
                    }
                  } catch (e) {
                    _showError('Failed to delete bin: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _clearAllBins() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Bins'),
            content: const Text(
              'Are you sure you want to remove all bins? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Get all bin documents
                    final snapshot = await _firestore.collection("Bins").get();

                    // Delete all bins
                    final batch = _firestore.batch();
                    for (var doc in snapshot.docs) {
                      batch.delete(doc.reference);
                    }
                    await batch.commit();

                    Navigator.pop(context);
                    _showSuccess('All bins cleared successfully!');
                  } catch (e) {
                    _showError('Failed to clear bins: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTruckInfoWindow(Map<String, dynamic> truck) {
    Color statusColor = _getStatusColor(truck['status'] ?? 'Unknown');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(truck['status'] ?? 'Unknown'),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                truck['licensePlate'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
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
                truck['status'] ?? 'Unknown',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (truck['assignedDriver'] != null &&
              truck['assignedDriver'] != 'Not assigned')
            Text(
              'Driver: ${truck['assignedDriver']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          if (truck['currentLocation'] != null &&
              truck['currentLocation'] != 'Not specified')
            Text(
              'Location: ${truck['currentLocation']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          if (truck['truckType'] != null)
            Text(
              'Type: ${truck['truckType']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          if (truck['lastUpdate'] != null)
            Text(
              'Last Update: ${_formatTimeAgo(truck['lastUpdate'])}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime updateTime;
      if (timestamp is Timestamp) {
        updateTime = timestamp.toDate();
      } else if (timestamp is String) {
        updateTime = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final difference = now.difference(updateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  List<Map<String, dynamic>> get _filteredTrucks {
    if (_selectedFilter == 'All') return _allTrucks;
    return _allTrucks
        .where((truck) => truck['status'] == _selectedFilter)
        .toList();
  }

  Widget _buildTruckList() {
    if (_filteredTrucks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Trucks Found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              _selectedFilter == 'All'
                  ? 'Add trucks in Truck Management'
                  : 'No trucks with status: $_selectedFilter',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredTrucks.length,
      itemBuilder: (context, index) {
        final truck = _filteredTrucks[index];
        Color statusColor = _getStatusColor(truck['status'] ?? 'Unknown');

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(truck['status'] ?? 'Unknown'),
                color: statusColor,
              ),
            ),
            title: Text(
              truck['licensePlate'] ?? 'Unknown Truck',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Driver: ${truck['assignedDriver'] ?? 'Not assigned'}'),
                if (truck['currentLocation'] != null &&
                    truck['currentLocation'] != 'Not specified')
                  Text('Location: ${truck['currentLocation']}'),
                if (truck['lastUpdate'] != null)
                  Text(
                    'Updated: ${_formatTimeAgo(truck['lastUpdate'])}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                truck['status'] ?? 'Unknown',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onTap: () {
              // Center map on this truck
              if (truck['currentLat'] != null && truck['currentLng'] != null) {
                _mapController.move(
                  LatLng(truck['currentLat']!, truck['currentLng']!),
                  15,
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsPanel() {
    final activeTrucks =
        _allTrucks.where((truck) => truck['status'] == 'Active').length;
    final availableTrucks =
        _allTrucks.where((truck) => truck['status'] == 'Available').length;
    final maintenanceTrucks =
        _allTrucks.where((truck) => truck['status'] == 'Maintenance').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total',
                _allTrucks.length.toString(),
                Icons.local_shipping,
              ),
              _buildStatItem(
                'Active',
                activeTrucks.toString(),
                Icons.directions_car,
                Colors.green,
              ),
              _buildStatItem(
                'Available',
                availableTrucks.toString(),
                Icons.check_circle,
                Colors.blue,
              ),
              _buildStatItem(
                'Maintenance',
                maintenanceTrucks.toString(),
                Icons.build,
                Colors.orange,
              ),
              _buildStatItem(
                'Bins',
                _bins.length.toString(),
                Icons.delete,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  ['All', 'Active', 'Available', 'Maintenance'].map((filter) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(filter),
                        selected: _selectedFilter == filter,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = selected ? filter : 'All';
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.purple[300],
                        labelStyle: TextStyle(
                          color:
                              _selectedFilter == filter
                                  ? Colors.white
                                  : Colors.purple[800],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.purple[700], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color ?? Colors.purple[700],
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Fleet Tracking - All Trucks",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple[700],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_isAddingBin)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _toggleAddBinMode,
              tooltip: 'Cancel Add Bin',
            )
          else
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              onPressed: _toggleAddBinMode,
              tooltip: 'Add Bin',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_bins':
                  _clearAllBins();
                  break;
                case 'refresh':
                  _loadAllTrucks();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_bins',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear All Bins'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Refresh Data'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading fleet data...'),
                  ],
                ),
              )
              : Column(
                children: [
                  // Stats Panel
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildStatsPanel(),
                  ),

                  // Map section
                  Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: const LatLng(
                              6.9271,
                              79.8612,
                            ), // Center of Sri Lanka
                            initialZoom: 8,
                            maxZoom: 18,
                            minZoom: 6,
                            onTap: (tapPosition, latLng) {
                              if (_isAddingBin) {
                                _showAddBinDialog(latLng);
                              }
                            },
                          ),
                          children: [
                            // Map Tiles
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.recycleapp',
                            ),

                            // Truck Markers
                            MarkerLayer(
                              markers:
                                  _filteredTrucks.map((truck) {
                                    if (truck['currentLat'] == null ||
                                        truck['currentLng'] == null) {
                                      return Marker(
                                        point: const LatLng(6.9271, 79.8612),
                                        width: 60,
                                        height: 60,
                                        child: const Icon(
                                          Icons.local_shipping,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                      );
                                    }

                                    Color statusColor = _getStatusColor(
                                      truck['status'] ?? 'Unknown',
                                    );

                                    return Marker(
                                      point: LatLng(
                                        truck['currentLat']!,
                                        truck['currentLng']!,
                                      ),
                                      width: 80,
                                      height: 80,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.local_shipping,
                                            color: statusColor,
                                            size: 40,
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 2,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              truck['licensePlate'] ??
                                                  'Unknown',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),

                            // Bin Markers
                            MarkerLayer(
                              markers:
                                  _bins.map((bin) {
                                    return Marker(
                                      point: bin.position,
                                      width: 45,
                                      height: 45,
                                      child: GestureDetector(
                                        onTap: () => _showBinDetails(bin),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 35,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),

                            // Map Attribution
                            RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                  'OpenStreetMap contributors',
                                  onTap:
                                      () => launchUrl(
                                        Uri.parse(
                                          'https://openstreetmap.org/copyright',
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Add Bin Mode Indicator
                        if (_isAddingBin)
                          Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_location_alt,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Tap anywhere on the map to add a bin at that location',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Info Button
                        Positioned(
                          top: _isAddingBin ? 80 : 16,
                          right: 16,
                          child: FloatingActionButton(
                            onPressed: _showFleetInfo,
                            backgroundColor: Colors.purple[700],
                            mini: true,
                            child: const Icon(Icons.info, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Truck list section
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Trucks ($_selectedFilter)",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_filteredTrucks.length}',
                                  style: TextStyle(
                                    color: Colors.purple[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(child: _buildTruckList()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showOptimizationOptions();
        },
        label: const Text("Optimize Routes"),
        icon: const Icon(Icons.route),
        backgroundColor: Colors.purple[700],
      ),
    );
  }

  void _showFleetInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Fleet Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Real-time Fleet Tracking:'),
                const SizedBox(height: 12),
                _buildInfoRow('Total Trucks', _allTrucks.length.toString()),
                _buildInfoRow(
                  'Active Trucks',
                  _allTrucks
                      .where((t) => t['status'] == 'Active')
                      .length
                      .toString(),
                ),
                _buildInfoRow(
                  'Available Trucks',
                  _allTrucks
                      .where((t) => t['status'] == 'Available')
                      .length
                      .toString(),
                ),
                _buildInfoRow(
                  'In Maintenance',
                  _allTrucks
                      .where((t) => t['status'] == 'Maintenance')
                      .length
                      .toString(),
                ),
                _buildInfoRow('Total Bins', _bins.length.toString()),
                const SizedBox(height: 12),
                const Text(
                  'Click on any truck in the list to center the map on it.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Text(
                  'Admins can add/remove bins that are visible to all drivers.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: Colors.purple[700])),
        ],
      ),
    );
  }

  void _showBinDetails(BinLocation bin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bin.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Recycling Bin',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteBinConfirmation(bin);
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: 'Delete Bin',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'LOCATION DETAILS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text('Latitude: ${bin.position.latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${bin.position.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _mapController.move(bin.position, 17);
                    _showInfo('Navigating to ${bin.name}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.navigation, color: Colors.white),
                  label: const Text(
                    'NAVIGATE TO BIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOptimizationOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Route Optimization",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Choose optimization strategy:",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.green),
                title: const Text('Fastest Routes'),
                subtitle: const Text('Minimize delivery time'),
                onTap: () {
                  Navigator.pop(context);
                  _optimizeRoutes('fastest');
                },
              ),
              ListTile(
                leading: const Icon(Icons.shortcut, color: Colors.blue),
                title: const Text('Shortest Distance'),
                subtitle: const Text('Minimize fuel consumption'),
                onTap: () {
                  Navigator.pop(context);
                  _optimizeRoutes('shortest');
                },
              ),
              ListTile(
                leading: const Icon(Icons.balance, color: Colors.orange),
                title: const Text('Balanced Approach'),
                subtitle: const Text('Balance time and distance'),
                onTap: () {
                  Navigator.pop(context);
                  _optimizeRoutes('balanced');
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.directions, color: Colors.purple),
                title: const Text('Generate Routes for Active Trucks'),
                subtitle: Text(
                  '${_allTrucks.where((t) => t['status'] == 'Active').length} active trucks available',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _generateActiveTruckRoutes();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _optimizeRoutes(String strategy) {
    final activeTrucks =
        _allTrucks.where((truck) => truck['status'] == 'Active').length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Optimizing routes for $activeTrucks active trucks using $strategy strategy...',
        ),
        backgroundColor: Colors.purple[700],
      ),
    );

    // TODO: Implement actual route optimization logic
    // This would integrate with a routing API like OSRM, Mapbox, etc.
  }

  void _generateActiveTruckRoutes() {
    final activeTrucks =
        _allTrucks.where((truck) => truck['status'] == 'Active').toList();

    if (activeTrucks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active trucks available for route generation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generating optimized routes for ${activeTrucks.length} active trucks...',
        ),
        backgroundColor: Colors.green,
      ),
    );

    // TODO: Implement route generation logic
  }
}

class BinLocation {
  final String name;
  final LatLng position;
  final String? id;

  BinLocation(this.name, this.position, {this.id});
}
