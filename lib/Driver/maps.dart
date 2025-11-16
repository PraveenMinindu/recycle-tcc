// lib/Driver/maps.dart
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

  // Bin locations (loaded from Firestore)
  final List<BinLocation> _bins = [];

  // Location streaming
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _binsStreamSubscription;
  bool _isTracking = false;
  bool _autoCenter = true;

  // Trip statistics
  double _totalDistance = 0.0;
  Position? _lastPosition;
  DateTime? _tripStartTime;

  // Movement detection
  bool _isMoving = false;
  double _movementThreshold = 5.0; // meters - consider movement above this
  int _stationaryCount = 0;
  int _stationaryThreshold =
      3; // number of consecutive updates to confirm stopped
  Position? _lastValidPosition;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _binsStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadDriverData();
    _loadBinsFromFirestore();
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

  // Update truck location in Firestore
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
        'isMoving': _isMoving, // Add movement status to Firestore
      });

      print(
        "Truck location updated in Firestore: ${position.latitude}, ${position.longitude} - Moving: $_isMoving",
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
        _lastValidPosition = position;
        _isMoving = false; // Assume stopped when getting single location
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

  bool _isValidPosition(Position newPosition) {
    // Filter out invalid positions (0,0 or extreme values)
    if (newPosition.latitude == 0.0 || newPosition.longitude == 0.0) {
      return false;
    }

    // Check for reasonable accuracy (less than 50 meters)
    if (newPosition.accuracy > 50.0) {
      return false;
    }

    return true;
  }

  Future<void> _handlePositionUpdate(Position newPosition) async {
    double distance = 0.0;

    // Calculate distance from last valid position
    if (_lastValidPosition != null) {
      distance = _calculateDistance(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
    }

    // Movement detection logic
    if (distance < _movementThreshold) {
      // Possible stopped - increment counter
      _stationaryCount++;

      if (_stationaryCount >= _stationaryThreshold) {
        // Confirmed stopped - don't update position unless significantly different
        if (_lastValidPosition != null) {
          double driftDistance = _calculateDistance(
            _lastValidPosition!.latitude,
            _lastValidPosition!.longitude,
            newPosition.latitude,
            newPosition.longitude,
          );

          // Only update if drift is more than 10 meters (significant movement)
          if (driftDistance > 10.0) {
            _updatePosition(newPosition, true);
          } else {
            // Small drift - maintain last valid position
            _updatePosition(_lastValidPosition!, false);
          }
        } else {
          _updatePosition(newPosition, true);
        }
      } else {
        // Not confirmed stopped yet - update position
        _updatePosition(newPosition, distance > _movementThreshold);
      }
    } else {
      // Moving - reset stationary counter and update position
      _stationaryCount = 0;
      _updatePosition(newPosition, true);
    }
  }

  void _updatePosition(Position position, bool isMoving) {
    setState(() {
      _currentPosition = position;
      _lastPosition = position;
      _isMoving = isMoving;
      _lastValidPosition = position;
    });

    // Update truck location in Firestore (REAL-TIME GPS TRACKING)
    _updateTruckLocationInFirestore(position);

    // Auto-center map on moving location only if moving
    if (_autoCenter && _isTracking && isMoving) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  void _startLiveTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Reduced to 5 meters for better accuracy
    );

    _tripStartTime = DateTime.now();
    _totalDistance = 0.0;
    _stationaryCount = 0;

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position newPosition) async {
        if (mounted) {
          // Check if this is a valid position (not GPS drift)
          if (_isValidPosition(newPosition)) {
            await _handlePositionUpdate(newPosition);
          }
        }
      },
      onError: (e) {
        print("Error in position stream: $e");
      },
    );

    setState(() {
      _isTracking = true;
      _isMoving = true; // Assume moving when starting
    });
    _showSuccess(
      'Live tracking started - Your movement is now visible to admin',
    );
  }

  void _stopLiveTracking() {
    _positionStreamSubscription?.cancel();
    setState(() {
      _isTracking = false;
      _isMoving = false;
      _tripStartTime = null;
      _stationaryCount = 0;
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

  void _resetTripStats() {
    setState(() {
      _totalDistance = 0.0;
      _tripStartTime = _isTracking ? DateTime.now() : null;
      _stationaryCount = 0;
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
              'Live GPS Tracking: ${_isMoving ? 'MOVING' : 'STOPPED'}',
              style: TextStyle(
                color: _isMoving ? Colors.green : Colors.orange,
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
                                            _isMoving
                                                ? Colors.orange
                                                : Colors.grey,
                                        size: 55,
                                      ),
                                      if (_isTracking)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color:
                                                  _isMoving
                                                      ? Colors.green
                                                      : Colors.grey,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (_isMoving
                                                          ? Colors.green
                                                          : Colors.grey)
                                                      .withOpacity(0.5),
                                                  blurRadius: 4,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _isMoving
                                                  ? Icons.gps_fixed
                                                  : Icons.local_parking,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      if (_autoCenter &&
                                          _isTracking &&
                                          _isMoving)
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
                                        Text(
                                          _isMoving ? 'MOVING' : 'STOPPED',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _isMoving
                                                    ? Colors.green
                                                    : Colors.orange,
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
                          color:
                              _isMoving
                                  ? Colors.green.withOpacity(0.9)
                                  : Colors.orange.withOpacity(0.9),
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
                              _isMoving ? Icons.gps_fixed : Icons.local_parking,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isMoving ? 'LIVE - MOVING' : 'LIVE - STOPPED',
                              style: const TextStyle(
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
                  color: _isMoving ? Colors.orange : const Color(0xFF00670c),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isMoving
                        ? 'MOVING - LIVE TRACKING'
                        : 'STOPPED - LIVE TRACKING',
                    style: TextStyle(
                      color:
                          _isMoving ? Colors.orange : const Color(0xFF00670c),
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
                        _isMoving
                            ? Colors.orange.withOpacity(0.2)
                            : const Color(0xFF00670c).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _isMoving ? Colors.orange : const Color(0xFF00670c),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _isMoving ? 'MOVING' : 'STOPPED',
                    style: TextStyle(
                      color:
                          _isMoving ? Colors.orange : const Color(0xFF00670c),
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
                  'Movement',
                  _isMoving ? 'Moving' : 'Stopped',
                  _isMoving ? Icons.directions_car : Icons.local_parking,
                  color: _isMoving ? Colors.green : Colors.orange,
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
                    Icon(
                      _isMoving ? Icons.gps_fixed : Icons.local_parking,
                      color: _isMoving ? Colors.green : Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isMoving
                          ? 'Moving - Admin can see your live location'
                          : 'Stopped - Location is stable',
                      style: TextStyle(
                        color: _isMoving ? Colors.green : Colors.orange,
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
                  'Status',
                  _isMoving ? 'Moving' : 'Stopped',
                  _isMoving ? Icons.directions_car : Icons.local_parking,
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
  final String? id;

  BinLocation(this.name, this.position, {this.id});
}
