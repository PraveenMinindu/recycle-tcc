// admin_rewards_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminRewardsManagement extends StatefulWidget {
  const AdminRewardsManagement({super.key});

  @override
  State<AdminRewardsManagement> createState() => _AdminRewardsManagementState();
}

class _AdminRewardsManagementState extends State<AdminRewardsManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _shopController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String _selectedCategory = 'Discount';
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rewards Management"),
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddRewardDialog,
            tooltip: 'Add New Reward',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Header
          _buildStatsHeader(),

          // Rewards List
          Expanded(child: _buildRewardsList()),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('user_rewards').snapshots(),
      builder: (context, snapshot) {
        int totalRedemptions = snapshot.hasData
            ? snapshot.data!.docs.length
            : 0;
        int activeRedemptions = snapshot.hasData
            ? snapshot.data!.docs
                  .where((doc) => doc['status'] == 'active')
                  .length
            : 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple[50],
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Rewards', '0', Icons.card_giftcard),
              _buildStatItem(
                'Redemptions',
                totalRedemptions.toString(),
                Icons.shopping_cart,
              ),
              _buildStatItem(
                'Active',
                activeRedemptions.toString(),
                Icons.check_circle,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple[700], size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildRewardsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('rewards').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rewards = snapshot.data!.docs;

        if (rewards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Rewards Available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to add your first reward',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final reward = rewards[index];
            final data = reward.data() as Map<String, dynamic>;

            return _buildRewardCard(reward.id, data);
          },
        );
      },
    );
  }

  Widget _buildRewardCard(String rewardId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.deepPurple[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getRewardIcon(data['category']),
            color: Colors.deepPurple[700],
          ),
        ),
        title: Text(
          data['title'] ?? 'No Title',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['description'] ?? 'No Description'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${data['pointsCost'] ?? 0} points'),
                const SizedBox(width: 16),
                Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(data['shopName'] ?? 'Unknown Shop'),
              ],
            ),
          ],
        ),
        trailing: Chip(
          backgroundColor: (data['isActive'] ?? false)
              ? Colors.green
              : Colors.red,
          label: Text(
            (data['isActive'] ?? false) ? 'Active' : 'Inactive',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        onTap: () => _showEditRewardDialog(rewardId, data),
      ),
    );
  }

  IconData _getRewardIcon(String category) {
    switch (category) {
      case 'Discount':
        return Icons.percent;
      case 'Free Item':
        return Icons.free_breakfast;
      case 'Voucher':
        return Icons.confirmation_number;
      default:
        return Icons.card_giftcard;
    }
  }

  void _showAddRewardDialog() {
    _clearForm();
    _showRewardDialog(isEditing: false);
  }

  void _showEditRewardDialog(String rewardId, Map<String, dynamic> data) {
    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _pointsController.text = (data['pointsCost'] ?? 0).toString();
    _shopController.text = data['shopName'] ?? '';
    _quantityController.text = (data['quantityAvailable'] ?? 0).toString();
    _selectedCategory = data['category'] ?? 'Discount';
    _isActive = data['isActive'] ?? true;

    _showRewardDialog(isEditing: true, rewardId: rewardId);
  }

  void _showRewardDialog({bool isEditing = false, String? rewardId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Reward' : 'Add New Reward'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Reward Title'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Points Cost'),
              ),
              TextField(
                controller: _shopController,
                decoration: const InputDecoration(labelText: 'Shop Name'),
              ),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity Available',
                ),
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: ['Discount', 'Free Item', 'Voucher'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _saveReward(isEditing, rewardId),
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
          if (isEditing)
            TextButton(
              onPressed: () => _deleteReward(rewardId!),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }

  Future<void> _saveReward(bool isEditing, String? rewardId) async {
    if (_titleController.text.isEmpty || _pointsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      final rewardData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'pointsCost': int.parse(_pointsController.text),
        'shopName': _shopController.text,
        'category': _selectedCategory,
        'quantityAvailable': int.tryParse(_quantityController.text) ?? 0,
        'isActive': _isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEditing && rewardId != null) {
        await _firestore.collection('rewards').doc(rewardId).update(rewardData);
      } else {
        await _firestore.collection('rewards').add(rewardData);
      }

      Navigator.pop(context);
      _clearForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Reward updated!' : 'Reward added!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteReward(String rewardId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reward'),
        content: const Text('Are you sure you want to delete this reward?'),
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

    if (confirm == true) {
      await _firestore.collection('rewards').doc(rewardId).delete();
      Navigator.pop(context); // Close the edit dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reward deleted')));
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _pointsController.clear();
    _shopController.clear();
    _quantityController.clear();
    _selectedCategory = 'Discount';
    _isActive = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _shopController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
