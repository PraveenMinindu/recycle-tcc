import 'package:flutter/material.dart';
import 'package:recycleapp/pages/helpsupport.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'package:recycleapp/services/auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _locationEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  String _language = 'English';
  String _distanceUnit = 'Kilometers';

  String? name, email;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  _loadUserData() async {
    name = await SharedpreferenceHelper().getUserName();
    email = await SharedpreferenceHelper().getUserEmail();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Settings Section (Only Personal Information remains)
            _buildSectionHeader("Account Settings"),
            _buildSettingsCard(
              children: [
                _buildSettingsItem(
                  icon: Icons.person_outline,
                  iconColor: Colors.blue,
                  title: "Personal Information",
                  subtitle: "Update your personal details",
                  onTap: () {
                    _showPersonalInfoDialog();
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Support Section (Help & Support now navigates to HelpSupportPage)
            _buildSectionHeader("Support"),
            _buildSettingsCard(
              children: [
                _buildSettingsItem(
                  icon: Icons.help_outline,
                  iconColor: Colors.orange,
                  title: "Help & Support",
                  subtitle: "Get help and contact support",
                  onTap: () {
                    print("Navigating to Help & Support Page from Settings");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HelpSupportPage(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingsItem(
                  icon: Icons.description_outlined,
                  iconColor: Colors.green,
                  title: "Terms of Service",
                  subtitle: "View terms and conditions",
                  onTap: () {
                    _showTermsDialog();
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // App Info
            _buildAppInfoCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C3E50),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          _buildInfoItem("App Version", "1.0.0"),
          _buildDivider(),
          _buildInfoItem("Build Number", "1"),
          _buildDivider(),
          _buildInfoItem("Last Updated", "November 2024"),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog Methods
  void _showPersonalInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Personal Information"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: ${name ?? 'Not set'}"),
              const SizedBox(height: 8),
              Text("Email: ${email ?? 'Not set'}"),
              const SizedBox(height: 16),
              const Text(
                "To update your personal information, please contact support.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Terms of Service"),
          content: SingleChildScrollView(
            child: Text(
              "This is where your app's terms and conditions would be displayed. "
              "Include user responsibilities, limitations of liability, and other "
              "important legal information.",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}
