import 'package:flutter/material.dart';
import 'package:recycleapp/Driver/onboarding.dart';
import 'package:recycleapp/Driver/complaint.dart';
import 'package:recycleapp/Driver/settings.dart';
import 'package:recycleapp/services/auth.dart';
import 'package:recycleapp/services/shared_pref.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String? id, name, email, image;
  bool _isLoading = true;

  getthesharedpref() async {
    id = await SharedpreferenceHelper().getUserId();
    name = await SharedpreferenceHelper().getUserName();
    email = await SharedpreferenceHelper().getUserEmail();
    image = await SharedpreferenceHelper().getUserImage();
    setState(() {
      _isLoading = false;
    });
  }

  ontheload() async {
    await getthesharedpref();
  }

  @override
  void initState() {
    ontheload();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileHeader(),
                    const SizedBox(height: 30),
                    _buildProfileOptions(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Profile Picture - Edit icon removed
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child:
                image != null && image!.isNotEmpty
                    ? Image.network(
                      image!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    )
                    : _buildDefaultAvatar(),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          name ?? "User Name",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          email ?? "user@example.com",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        // Profile Completion removed
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 50, color: Color(0xFF4CAF50)),
    );
  }

  Widget _buildProfileOptions() {
    return Column(
      children: [
        _buildProfileOption(
          icon: Icons.person_outline,
          title: "Personal Information",
          subtitle: "Update your personal details",
          iconColor: Colors.blue,
          onTap: _showPersonalInfo,
        ),
        // Activity History removed
        // Environmental Impact removed
        _buildProfileOption(
          icon: Icons.report_problem,
          title: "Submit Complaint",
          subtitle: "Report issues or concerns",
          iconColor: Colors.orange,
          onTap: () {
            print("Navigating to Complaint Page");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DriverComplaintPage(),
              ),
            );
          },
        ),
        // Settings button
        _buildProfileOption(
          icon: Icons.settings,
          title: "Settings",
          subtitle: "App preferences and configurations",
          iconColor: Colors.grey,
          onTap: () {
            print("=== SETTINGS BUTTON TAPPED ===");
            _testSettingsNavigation();
          },
        ),
      ],
    );
  }

  // TEST METHOD FOR SETTINGS NAVIGATION
  void _testSettingsNavigation() {
    print("1. Starting navigation to Settings...");

    try {
      print("2. Creating MaterialPageRoute...");
      final route = MaterialPageRoute(
        builder: (context) {
          print("3. Building SettingsPage...");
          return const SettingsPage();
        },
      );

      print("4. Calling Navigator.push...");
      Navigator.push(context, route)
          .then((value) {
            print("5. Navigation completed successfully");
          })
          .catchError((error) {
            print("5. Navigation error: $error");
          });
    } catch (e) {
      print("ERROR in navigation: $e");
      _showErrorDialog("Navigation Error", e.toString());
    }
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.grey,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.logout,
          title: "Logout",
          subtitle: "Sign out from your account",
          iconColor: Colors.orange,
          backgroundColor: Colors.orange.withOpacity(0.1),
          onTap: _showLogoutConfirmation,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.delete_outline,
          title: "Delete Account",
          subtitle: "Permanently delete your account",
          iconColor: Colors.red,
          backgroundColor: Colors.red.withOpacity(0.1),
          onTap: _showDeleteAccountConfirmation,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: iconColor,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: iconColor.withOpacity(0.7)),
        ),
        trailing: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_forward_ios, size: 14, color: iconColor),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  // Edit Profile Dialog removed

  void _showPersonalInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Personal Information"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow("Name", name ?? "Not set"),
                  _buildInfoRow("Email", email ?? "Not set"),
                  _buildInfoRow("User ID", id ?? "Not set"),
                  const SizedBox(height: 16),
                  const Text(
                    "To update your information, please visit the Settings page or contact support.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _testSettingsNavigation();
                },
                child: const Text("Settings"),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // Coming Soon Dialog removed (no longer needed)

  void _showLogoutConfirmation() async {
    final shouldLogout = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Logout"),
            content: const Text(
              "Are you sure you want to logout from your account?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      _performLogout();
    }
  }

  void _showDeleteAccountConfirmation() async {
    final shouldDelete = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Account"),
            content: const Text(
              "This action cannot be undone. All your data including recycling history, complaints, and personal information will be permanently deleted.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Delete Account",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      _performAccountDeletion();
    }
  }

  void _performLogout() async {
    try {
      await AuthMethods().signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Onboarding()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error occurred during logout"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _performAccountDeletion() async {
    try {
      await AuthMethods().deleteUser();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Onboarding()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error occurred during account deletion"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
