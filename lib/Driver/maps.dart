import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'dart:async';
import 'dart:math';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final MapController _mapController = MapController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Position? _currentPosition;
  bool _isLoading = true;

  // Truck data
  Map<String, dynamic>? _assignedTruck;
  String? _driverId;

  // Bin locations (empty initially - driver will add them)
  final List<BinLocation> _bins = [];

  // Add bin mode
  bool _isAddingBin = false;
  final TextEditingController _binNameController = TextEditingController();

  // Location streaming
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  bool _autoCenter = true;

  // Trip statistics
  double _totalDistance = 0.0;
  Position? _lastPosition;
  DateTime? _tripStartTime;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _binNameController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadDriverData();
    _getCurrentLocation();
  }

  Future<void> _loadDriverData() async {
    try {
      _driverId = await SharedpreferenceHelper().getUserId();

      if (_driverId != null) {
        // Listen for truck assignment changes
        _firestore
            .collection("Trucks")
            .where("driverId", isEqualTo: _driverId)
            .snapshots()
            .listen((snapshot) {
              if (mounted) {
                setState(() {
                  if (snapshot.docs.isNotEmpty) {
                    final doc = snapshot.docs.first;
                    final data = doc.data() as Map<String, dynamic>;
                    _assignedTruck = {'id': doc.id, ...data};
                  } else {
                    _assignedTruck = null;
                  }
                });
              }
            });
      }
    } catch (e) {
      print("Error loading driver data: $e");
    }
  }

  // NEW: Update truck location in Firestore
  Future<void> _updateTruckLocationInFirestore(Position position) async {
    if (_assignedTruck == null || _assignedTruck!['id'] == null) return;

    try {
      await _firestore.collection("Trucks").doc(_assignedTruck!['id']).update({
        'currentLat': position.latitude,
        'currentLng': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'currentLocation':
            'GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      print(
        "Truck location updated in Firestore: ${position.latitude}, ${position.longitude}",
      );
    } catch (e) {
      print("Error updating truck location in Firestore: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _lastPosition = position;
      });

      // Update truck location in Firestore
      await _updateTruckLocationInFirestore(position);

      // Center map on current location
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    } catch (e) {
      _showError('Error getting location: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startLiveTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10, // Update every 10 meters
    );

    _tripStartTime = DateTime.now();
    _totalDistance = 0.0;

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position newPosition) async {
        if (mounted) {
          // Calculate distance traveled
          if (_lastPosition != null) {
            double distance = _calculateDistance(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              newPosition.latitude,
              newPosition.longitude,
            );
            _totalDistance += distance;
          }

          setState(() {
            _currentPosition = newPosition;
            _lastPosition = newPosition;
          });

          // Update truck location in Firestore (REAL-TIME GPS TRACKING)
          await _updateTruckLocationInFirestore(newPosition);

          // Auto-center map on moving location
          if (_autoCenter && _isTracking) {
            _mapController.move(
              LatLng(newPosition.latitude, newPosition.longitude),
              _mapController.camera.zoom,
            );
          }
        }
      },
      onError: (e) {
        print("Error in position stream: $e");
      },
    );

    setState(() {
      _isTracking = true;
    });
    _showSuccess(
      'Live tracking started - Your movement is now visible to admin',
    );
  }

  void _stopLiveTracking() {
    _positionStreamSubscription?.cancel();
    setState(() {
      _isTracking = false;
      _tripStartTime = null;
    });
    _showSuccess('Live tracking stopped');
  }

  void _toggleTracking() {
    if (_isTracking) {
      _stopLiveTracking();
    } else {
      _startLiveTracking();
    }
  }

  void _toggleAutoCenter() {
    setState(() {
      _autoCenter = !_autoCenter;
    });
    _showInfo(_autoCenter ? 'Auto-center enabled' : 'Auto-center disabled');
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(DateTime? startTime) {
    if (startTime == null) return '0 min';
    final duration = DateTime.now().difference(startTime);
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = duration.inHours;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
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

  void _centerOnCurrentLocation() async {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15,
      );
      _showInfo('Centered on current location');
    } else {
      await _getCurrentLocation();
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

  void _addBinAtCurrentLocation() {
    if (_currentPosition == null) {
      _showError('Cannot get current location');
      return;
    }

    _showAddBinDialog(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    );
  }

  void _clearAllBins() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Bins'),
            content: const Text('Are you sure you want to remove all bins?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _bins.clear());
                  Navigator.pop(context);
                  _showSuccess('All bins cleared');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );
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
                onPressed: () {
                  if (_binNameController.text.trim().isEmpty) {
                    _showError('Please enter bin name');
                    return;
                  }

                  setState(() {
                    _bins.add(
                      BinLocation(_binNameController.text.trim(), position),
                    );
                  });

                  _binNameController.clear();
                  Navigator.pop(context);
                  _showSuccess('Bin added successfully!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00670c),
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

  void _resetTripStats() {
    setState(() {
      _totalDistance = 0.0;
      _tripStartTime = _isTracking ? DateTime.now() : null;
    });
    _showInfo('Trip statistics reset');
  }

  // Build truck info widget for the map
  Widget _buildTruckInfoWidget() {
    if (_assignedTruck == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping, color: Colors.grey[600], size: 16),
            const SizedBox(width: 8),
            Text(
              'No Truck Assigned',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    Color statusColor;
    switch (_assignedTruck!['status']) {
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
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
              Icon(Icons.local_shipping, color: Colors.green[700], size: 16),
              const SizedBox(width: 8),
              Text(
                _assignedTruck!['licensePlate'] ?? 'Unknown Truck',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF00670c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
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
                _assignedTruck!['status'] ?? 'Unknown',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_assignedTruck!['truckType'] != null &&
              _assignedTruck!['truckType'] != 'Not specified')
            Text(
              _assignedTruck!['truckType'],
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          if (_isTracking)
            Text(
              'Live GPS Tracking: ON',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Driver - Live Tracking'),
        backgroundColor: const Color(0xFF00670c),
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(
              _autoCenter ? Icons.center_focus_strong : Icons.center_focus_weak,
            ),
            onPressed: _toggleAutoCenter,
            tooltip: _autoCenter ? 'Auto-center ON' : 'Auto-center OFF',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Center on Location',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'add_bin':
                  _toggleAddBinMode();
                  break;
                case 'clear_bins':
                  _clearAllBins();
                  break;
                case 'start_tracking':
                  _startLiveTracking();
                  break;
                case 'stop_tracking':
                  _stopLiveTracking();
                  break;
                case 'reset_stats':
                  _resetTripStats();
                  break;
                case 'update_location':
                  _getCurrentLocation();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'add_bin',
                    child: Row(
                      children: [
                        Icon(Icons.add_location, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Add Bin Mode'),
                      ],
                    ),
                  ),
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
                  const PopupMenuDivider(),
                  if (!_isTracking)
                    const PopupMenuItem(
                      value: 'start_tracking',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Start Live Tracking'),
                        ],
                      ),
                    ),
                  if (_isTracking)
                    const PopupMenuItem(
                      value: 'stop_tracking',
                      child: Row(
                        children: [
                          Icon(Icons.stop, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Stop Live Tracking'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'update_location',
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Update Location Now'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset_stats',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Reset Trip Stats'),
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
                    Text('Getting your location...'),
                  ],
                ),
              )
              : Stack(
                children: [
                  // Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _currentPosition != null
                              ? LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              )
                              : const LatLng(6.9271, 79.8612),
                      initialZoom: 15,
                      maxZoom: 18,
                      minZoom: 10,
                      onTap: (tapPosition, latLng) {
                        if (_isAddingBin) {
                          _showAddBinDialog(latLng);
                          setState(() => _isAddingBin = false);
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

                      // Truck Marker (Your Real Location)
                      if (_currentPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              width: 120, // Increased width to accommodate text
                              height:
                                  90, // Increased height to accommodate text
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Truck Icon with Status
                                  Stack(
                                    children: [
                                      Icon(
                                        Icons.local_shipping,
                                        color:
                                            _isTracking
                                                ? Colors.orange
                                                : const Color(0xFF00670c),
                                        size: 55,
                                      ),
                                      if (_isTracking)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green
                                                      .withOpacity(0.5),
                                                  blurRadius: 4,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.gps_fixed,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      if (_autoCenter && _isTracking)
                                        Positioned(
                                          left: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.navigation,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  // Truck Name/Info
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 2,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          _assignedTruck?['licensePlate'] ??
                                              'No Truck',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00670c),
                                          ),
                                        ),
                                        if (_isTracking)
                                          Text(
                                            'LIVE',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
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
                                          color: Colors.black.withOpacity(0.2),
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

                  // Status Panel
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _buildStatusPanel(),
                  ),

                  // Truck Info Panel (Top Right)
                  Positioned(
                    top: 140,
                    right: 16,
                    child: _buildTruckInfoWidget(),
                  ),

                  // Add Bin Mode Indicator
                  if (_isAddingBin)
                    Positioned(
                      top: 140,
                      left: 0,
                      right: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
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

                  // Trip Statistics Panel
                  if (_isTracking)
                    Positioned(
                      bottom: 120,
                      left: 16,
                      right: 16,
                      child: _buildTripStatsPanel(),
                    ),

                  // GPS Tracking Indicator
                  if (_isTracking)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'LIVE GPS TRACKING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Tracking Button (Main Action)
          FloatingActionButton(
            onPressed: _toggleTracking,
            backgroundColor:
                _isTracking ? Colors.orange : const Color(0xFF00670c),
            elevation: 4,
            child: Icon(
              _isTracking ? Icons.gps_off : Icons.gps_fixed,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),

          // Add Bin Button
          FloatingActionButton(
            onPressed:
                _isAddingBin ? _toggleAddBinMode : _addBinAtCurrentLocation,
            backgroundColor:
                _isAddingBin ? Colors.orange : const Color(0xFF00670c),
            elevation: 3,
            child: Icon(
              _isAddingBin ? Icons.cancel : Icons.add_location_alt,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),

          // Zoom Controls
          FloatingActionButton.small(
            onPressed:
                () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                ),
            backgroundColor: const Color(0xFF00670c),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed:
                () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                ),
            backgroundColor: const Color(0xFF00670c),
            child: const Icon(Icons.remove, color: Colors.white),
          ),
          const SizedBox(height: 12),

          // Location Button
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            backgroundColor: Colors.blue,
            elevation: 3,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: _isTracking ? Colors.orange : const Color(0xFF00670c),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isTracking ? 'LIVE TRACKING ACTIVE' : 'TRUCK READY',
                    style: TextStyle(
                      color:
                          _isTracking ? Colors.orange : const Color(0xFF00670c),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isTracking
                            ? Colors.orange.withOpacity(0.2)
                            : const Color(0xFF00670c).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _isTracking ? Colors.orange : const Color(0xFF00670c),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _isTracking ? 'LIVE' : 'READY',
                    style: TextStyle(
                      color:
                          _isTracking ? Colors.orange : const Color(0xFF00670c),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoItem('Bins', '${_bins.length}', Icons.delete),
                const SizedBox(width: 16),
                _buildInfoItem(
                  'Status',
                  _isTracking ? 'Moving' : 'Stopped',
                  Icons.circle,
                  color: _isTracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 16),
                _buildInfoItem(
                  'Auto-center',
                  _autoCenter ? 'ON' : 'OFF',
                  Icons.center_focus_strong,
                  color: _autoCenter ? Colors.blue : Colors.grey,
                ),
              ],
            ),
            // Truck info in status panel
            if (_assignedTruck != null) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey[300]),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: Colors.green[700],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _assignedTruck!['licensePlate'] ?? 'Unknown Truck',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF00670c),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _assignedTruck!['status'] == 'Active'
                              ? Colors.green.withOpacity(0.1)
                              : _assignedTruck!['status'] == 'Maintenance'
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _assignedTruck!['status'] ?? 'Unknown',
                      style: TextStyle(
                        color:
                            _assignedTruck!['status'] == 'Active'
                                ? Colors.green
                                : _assignedTruck!['status'] == 'Maintenance'
                                ? Colors.orange
                                : Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isTracking) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.gps_fixed, color: Colors.green, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Admin can see your live location',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripStatsPanel() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TRIP STATISTICS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Distance',
                  _formatDistance(_totalDistance),
                  Icons.directions_car,
                ),
                _buildStatItem(
                  'Duration',
                  _formatDuration(_tripStartTime),
                  Icons.timer,
                ),
                _buildStatItem(
                  'Speed',
                  '${_currentPosition?.speed.toStringAsFixed(1) ?? '0'} m/s',
                  Icons.speed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.grey,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00670c), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF00670c),
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
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
                      setState(() => _bins.remove(bin));
                      Navigator.pop(context);
                      _showSuccess('Bin "${bin.name}" removed');
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: 'Remove Bin',
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
                    backgroundColor: const Color(0xFF00670c),
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
}

class BinLocation {
  final String name;
  final LatLng position;

  BinLocation(this.name, this.position);
}
