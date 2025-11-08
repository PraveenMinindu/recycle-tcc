import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteOptimization extends StatefulWidget {
  const RouteOptimization({super.key});

  @override
  State<RouteOptimization> createState() => _RouteOptimizationState();
}

class _RouteOptimizationState extends State<RouteOptimization> {
  late GoogleMapController _mapController;

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId("pickup1"),
      position: LatLng(37.7749, -122.4194),
      infoWindow: InfoWindow(title: "Pickup Point 1"),
    ),
    const Marker(
      markerId: MarkerId("pickup2"),
      position: LatLng(37.7849, -122.4094),
      infoWindow: InfoWindow(title: "Pickup Point 2"),
    ),
  };

  final List<Map<String, String>> _routes = [
    {"truck": "Truck 1", "distance": "12 km", "time": "25 mins"},
    {"truck": "Truck 2", "distance": "18 km", "time": "40 mins"},
    {"truck": "Truck 3", "distance": "9 km", "time": "15 mins"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Route Optimization",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Map section
          Expanded(
            flex: 2,
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.7749, -122.4194),
                zoom: 12,
              ),
              markers: _markers,
            ),
          ),

          // Route list section
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
                  const Text(
                    "Optimized Routes",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        final route = _routes[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.local_shipping,
                              color: Colors.purple,
                            ),
                            title: Text(route["truck"]!),
                            subtitle: Text(
                              "Distance: ${route["distance"]} | ETA: ${route["time"]}",
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement real route optimization logic
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Optimizing routes...")));
        },
        label: const Text("Optimize Routes"),
        icon: const Icon(Icons.route),
        backgroundColor: Colors.purple[700],
      ),
    );
  }
}
