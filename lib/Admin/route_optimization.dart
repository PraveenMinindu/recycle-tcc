import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  final MapController _mapController = MapController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _allTrucks = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  // Real truck positions (will be updated from driver GPS)
  final Map<String, LatLng> _truckPositions = {};

  @override
  void initState() {
    super.initState();
    _loadAllTrucks();
  }

  Future<void> _loadAllTrucks() async {
    try {
      _firestore.collection("Trucks").snapshots().listen((snapshot) {
        if (mounted) {
          setState(() {
            _allTrucks =
                snapshot.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Get truck position - use real GPS data if available, otherwise use default
                  double lat =
                      data['currentLat'] ??
                      _getDefaultLat(data['licensePlate']);
                  double lng =
                      data['currentLng'] ??
                      _getDefaultLng(data['licensePlate']);

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
      });
    } catch (e) {
      print("Error loading trucks: $e");
      setState(() => _isLoading = false);
    }
  }

  // Default positions for demo (centered around Sri Lanka)
  double _getDefaultLat(String licensePlate) {
    // Generate somewhat unique positions based on license plate
    int hash = licensePlate.hashCode;
    return 6.9271 + ((hash % 100) - 50) * 0.1; // Base: Colombo
  }

  double _getDefaultLng(String licensePlate) {
    int hash = licensePlate.hashCode;
    return 79.8612 + ((hash % 100) - 50) * 0.1; // Base: Colombo
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
                _getStatusIcon(truck['status']),
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
        Color statusColor = _getStatusColor(truck['status']);

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
              child: Icon(_getStatusIcon(truck['status']), color: statusColor),
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
                  LatLng(truck['currentLat'], truck['currentLng']),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllTrucks,
            tooltip: 'Refresh',
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
                                        truck['currentLat'],
                                        truck['currentLng'],
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

                        // Info Button
                        Positioned(
                          top: 16,
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
                const SizedBox(height: 12),
                const Text(
                  'Click on any truck in the list to center the map on it.',
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
