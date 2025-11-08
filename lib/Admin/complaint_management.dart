import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintManagement extends StatelessWidget {
  const ComplaintManagement({super.key});

  void _showComplaintDetails(
    BuildContext context,
    String complaintId,
    Map<String, dynamic> complaint,
  ) {
    // Mark as read when admin views the complaint
    _markAsRead(complaintId);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(complaint['title'] ?? 'Complaint Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow(
                    'Driver',
                    complaint['driverName'] ?? 'Unknown',
                  ),
                  _buildDetailRow(
                    'Truck',
                    complaint['truckLicensePlate'] ?? 'Unknown',
                  ),
                  _buildDetailRow(
                    'Category',
                    complaint['category'] ?? 'Unknown',
                  ),
                  _buildDetailRow(
                    'Priority',
                    complaint['priority'] ?? 'Medium',
                  ),
                  _buildDetailRow(
                    'Location',
                    complaint['location'] ?? 'Not specified',
                  ),
                  _buildDetailRow(
                    'Status',
                    _getDisplayStatus(complaint['status'] ?? 'Unread'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(complaint['description'] ?? 'No description provided'),

                  // Display images if available
                  if (complaint['imageUrls'] != null &&
                      (complaint['imageUrls'] as List).isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Attached Images:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (complaint['imageUrls'] as List).length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      complaint['imageUrls'][index],
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () => _deleteComplaint(context, complaintId),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'In Progress':
        return Colors.blue;
      case 'Read':
        return Colors.blueGrey;
      case 'Unread':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getDisplayStatus(String status) {
    // Convert internal status to display status
    if (status == 'Pending') {
      return 'Unread';
    }
    return status;
  }

  String _getInternalStatus(String displayStatus) {
    // Convert display status to internal status
    if (displayStatus == 'Unread') {
      return 'Pending';
    }
    return displayStatus;
  }

  Future<void> _markAsRead(String complaintId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Complaints')
          .doc(complaintId)
          .update({
            'status': 'Read',
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error marking complaint as read: $e');
    }
  }

  Future<void> _deleteComplaint(
    BuildContext context,
    String complaintId,
  ) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Complaint'),
            content: const Text(
              'Are you sure you want to delete this complaint? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('Complaints')
            .doc(complaintId)
            .delete();

        // Close the details dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete complaint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Complaints'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('Complaints')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading complaints',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Complaints',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All complaints have been resolved',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var complaint = snapshot.data!.docs[index];
              var data = complaint.data() as Map<String, dynamic>;
              String displayStatus = _getDisplayStatus(
                data['status'] ?? 'Unread',
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: ListTile(
                  title: Text(
                    data['title'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Driver: ${data['driverName'] ?? 'Unknown'}'),
                      Text('Truck: ${data['truckLicensePlate'] ?? 'Unknown'}'),
                      Text('Priority: ${data['priority'] ?? 'Medium'}'),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      displayStatus,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(
                      data['status'] ?? 'Unread',
                    ),
                  ),
                  onTap: () {
                    _showComplaintDetails(context, complaint.id, data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
