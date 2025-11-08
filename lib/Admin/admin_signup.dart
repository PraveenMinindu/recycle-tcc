import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:recycleapp/Admin/admin_login.dart';
import 'package:recycleapp/services/widget_support.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSignup extends StatefulWidget {
  const AdminSignup({super.key});

  @override
  State<AdminSignup> createState() => _AdminSignupState();
}

class _AdminSignupState extends State<AdminSignup> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Back Button
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back_ios, color: Colors.green[700]),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 20),

                // Create Account Text
                Text(
                  "Create Admin Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Fill in your details to create an admin account",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                // Full Name Field
                Text(
                  "Full Name",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter your full name",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Email Field
                Text(
                  "Email",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter your email",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Username Field
                Text(
                  "Username",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Choose a username",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Field
                Text(
                  "Password",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Create a password",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Colors.green[700],
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[500],
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Confirm Password Field
                Text(
                  "Confirm Password",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Confirm your password",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Colors.green[700],
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[500],
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : signUpAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              "Sign Up",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 32),

                // OR Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Google Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      showSnackBar("Google sign up for admin coming soon");
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("images/google.png", height: 24, width: 24),
                        const SizedBox(width: 12),
                        Text(
                          "Sign Up with Google",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Login Redirect
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminLogin(),
                            ),
                          );
                        },
                        child: Text(
                          "Log in",
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simple hash function
  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    int hash = 0;
    for (var i = 0; i < bytes.length; i++) {
      hash = (hash << 5) - hash + bytes[i];
      hash = hash & hash;
    }
    return hash.abs().toString();
  }

  // Admin Sign Up Method
  Future<void> signUpAdmin() async {
    String fullName = fullNameController.text.trim();
    String email = emailController.text.trim();
    String username = usernameController.text.trim().toLowerCase();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // Input validation
    if (fullName.isEmpty ||
        email.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showSnackBar("Please fill in all fields");
      return;
    }

    if (fullName.length < 2) {
      showSnackBar("Please enter a valid full name");
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      showSnackBar("Please enter a valid email address");
      return;
    }

    if (username.length < 3) {
      showSnackBar("Username must be at least 3 characters");
      return;
    }

    if (password.length < 6) {
      showSnackBar("Password must be at least 6 characters");
      return;
    }

    if (password != confirmPassword) {
      showSnackBar("Passwords do not match");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Check if username already exists
      QuerySnapshot usernameSnapshot = await FirebaseFirestore.instance
          .collection("Admin")
          .where("id", isEqualTo: username)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (usernameSnapshot.docs.isNotEmpty) {
        showSnackBar("Username already exists");
        return;
      }

      // Check if email already exists
      QuerySnapshot emailSnapshot = await FirebaseFirestore.instance
          .collection("Admin")
          .where("email", isEqualTo: email)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (emailSnapshot.docs.isNotEmpty) {
        showSnackBar("Email already registered");
        return;
      }

      // Create new admin account
      String adminId = DateTime.now().millisecondsSinceEpoch.toString();
      String hashedPassword = hashPassword(password);

      Map<String, dynamic> adminData = {
        "id": username,
        "email": email,
        "fullName": fullName,
        "password": hashedPassword,
        "createdAt": FieldValue.serverTimestamp(),
        "role": "admin",
        "isActive": true,
      };

      await FirebaseFirestore.instance
          .collection("Admin")
          .doc(adminId)
          .set(adminData);

      showSuccessSnackBar("Admin account created successfully!");

      // Navigate to login after short delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminLogin()),
        );
      }
    } on FirebaseException catch (e) {
      showSnackBar("Network error: ${e.message}");
    } on TimeoutException catch (_) {
      showSnackBar("Connection timeout. Please try again.");
    } catch (e) {
      showSnackBar("An unexpected error occurred: ${e.toString()}");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Success SnackBar
  void showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[700],
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Error SnackBar
  void showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[700],
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
