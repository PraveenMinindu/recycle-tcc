import 'package:flutter/material.dart';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycling Locations'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              // Placeholder for location function
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Google Maps Placeholder',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Map will be displayed here once\nGoogle Maps API is configured',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _showLocationLegend(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'View Location Legend',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: () {
              // Placeholder for zoom in
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            onPressed: () {
              // Placeholder for zoom out
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.remove, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showLocationLegend(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Legend'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLegendItem('Recycling Center', Colors.green),
                _buildLegendItem('E-Waste Drop-off', Colors.blue),
                _buildLegendItem('Recycling Bin', Colors.orange),
                _buildLegendItem('Collection Point', Colors.purple),
                const SizedBox(height: 10),
                const Text(
                  'Google Maps integration will be enabled once API key is configured',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }
}
