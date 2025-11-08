import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:recycleapp/Admin/home_admin.dart';
import 'package:recycleapp/Admin/admin_signup.dart';
import 'package:recycleapp/services/widget_support.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  bool isGoogleLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Google Sign-In configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
  );

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  // Check if admin is already logged in
  Future<void> _checkExistingLogin() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isAdminLoggedIn') ?? false;

      if (isLoggedIn && mounted) {
        // Verify the session is still valid by checking Firebase Auth
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          // User is still authenticated with Firebase
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeAdmin()),
          );
        } else {
          // Firebase session expired, clear local storage
          await prefs.setBool('isAdminLoggedIn', false);
          await prefs.remove('adminIdentifier');
        }
      }
    } catch (e) {
      print("Error checking login status: $e");
    }
  }

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
                const SizedBox(height: 60),

                // Welcome Back Text
                Text(
                  "Log In to your account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Welcome back! Please enter your details.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 60),

                // Username/Email Field
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
                      hintText: "Enter your username",
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
                const SizedBox(height: 24),

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
                      hintText: "Enter your password",
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
                const SizedBox(height: 16),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      showSnackBar("Forgot password feature coming soon");
                    },
                    child: Text(
                      "Forgot password?",
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginAdmin,
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
                              "Log In",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 40),

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

                // Google Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: isGoogleLoading ? null : signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        isGoogleLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey,
                                ),
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "images/google.png",
                                  height: 24,
                                  width: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Log In with Google",
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
                const SizedBox(height: 40),

                // Sign Up Redirect
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminSignup(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign up",
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

  // Save login activity to Firebase
  Future<void> _saveLoginActivity(
    String username,
    String loginMethod, {
    String? email,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      String loginId = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> loginData = {
        "loginId": loginId,
        "username": username,
        "email": email,
        "loginMethod": loginMethod,
        "success": success,
        "timestamp": FieldValue.serverTimestamp(),
        "deviceInfo": {
          "platform": "mobile",
          "timezone": DateTime.now().timeZoneName,
        },
        "errorMessage": errorMessage,
      };

      await _firestore
          .collection("AdminLoginActivity")
          .doc(loginId)
          .set(loginData);

      print("Login activity saved for: $username");
    } catch (e) {
      print("Error saving login activity: $e");
    }
  }

  // Google Sign In Method with forced account selection
  Future<void> signInWithGoogle() async {
    setState(() {
      isGoogleLoading = true;
    });

    try {
      // Always sign out from Google to force account selection
      await _googleSignIn.signOut();

      // Show account selection
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          isGoogleLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // Check if this Google user is an admin in Firestore
        await _checkGoogleAdmin(user);
      } else {
        showSnackBar("Google sign-in failed");
      }
    } catch (e) {
      print("Google sign-in error: $e");

      // More specific error messages
      if (e is FirebaseAuthException) {
        showSnackBar("Authentication error: ${e.message}");
      } else {
        showSnackBar("Error signing in with Google");
      }
    } finally {
      if (mounted) {
        setState(() {
          isGoogleLoading = false;
        });
      }
    }
  }

  // Check if Google user is an admin
  Future<void> _checkGoogleAdmin(User user) async {
    try {
      // Check if user exists in Admin collection with this email
      QuerySnapshot snapshot = await _firestore
          .collection("Admin")
          .where("email", isEqualTo: user.email)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isNotEmpty) {
        // User is an admin, proceed to home
        var adminData = snapshot.docs.first.data() as Map<String, dynamic>;
        String username = adminData["id"] ?? user.email!.split('@')[0];

        // Save successful login activity
        await _saveLoginActivity(username, "google", email: user.email);

        await _saveLoginState(user.email!);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeAdmin()),
            (route) => false,
          );
        }
      } else {
        // User is not registered as admin
        await _saveLoginActivity(
          user.email!,
          "google",
          success: false,
          errorMessage: "Not registered as admin",
        );
        await _auth.signOut();
        await _googleSignIn.signOut();
        showSnackBar("This Google account is not registered as an admin");
      }
    } catch (e) {
      print("Error checking admin status: $e");
      await _saveLoginActivity(
        "unknown",
        "google",
        success: false,
        errorMessage: e.toString(),
      );
      showSnackBar("Error verifying admin access");
    }
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

  // Admin Login Method
  Future<void> loginAdmin() async {
    String username = usernameController.text.trim().toLowerCase();
    String password = passwordController.text.trim();

    // Input validation
    if (username.isEmpty || password.isEmpty) {
      showSnackBar("Please fill in both fields");
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

    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await _firestore
          .collection("Admin")
          .where("id", isEqualTo: username)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        // Save failed login attempt
        await _saveLoginActivity(
          username,
          "username_password",
          success: false,
          errorMessage: "Invalid username",
        );
        showSnackBar("Invalid username or password");
      } else {
        var adminData = snapshot.docs.first.data() as Map<String, dynamic>;
        String storedPassword = adminData["password"] ?? "";
        String email = adminData["email"] ?? "";

        // Compare passwords (with hashing if available)
        if (storedPassword == hashPassword(password)) {
          // Save successful login activity
          await _saveLoginActivity(username, "username_password", email: email);

          // Save login state
          await _saveLoginState(username);

          // Login successful
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeAdmin()),
              (route) => false,
            );
          }
        } else {
          // Save failed login attempt
          await _saveLoginActivity(
            username,
            "username_password",
            email: email,
            success: false,
            errorMessage: "Invalid password",
          );
          showSnackBar("Invalid username or password");
        }
      }
    } on FirebaseException catch (e) {
      await _saveLoginActivity(
        username,
        "username_password",
        success: false,
        errorMessage: "Firebase error: ${e.message}",
      );
      showSnackBar("Network error: ${e.message}");
    } on TimeoutException catch (_) {
      await _saveLoginActivity(
        username,
        "username_password",
        success: false,
        errorMessage: "Connection timeout",
      );
      showSnackBar("Connection timeout. Please try again.");
    } catch (e) {
      await _saveLoginActivity(
        username,
        "username_password",
        success: false,
        errorMessage: "Unexpected error: $e",
      );
      showSnackBar("An unexpected error occurred");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Save login state to shared preferences
  Future<void> _saveLoginState(String identifier) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdminLoggedIn', true);
      await prefs.setString('adminIdentifier', identifier);
    } catch (e) {
      print("Error saving login state: $e");
    }
  }

  // SnackBar Helper
  void showSnackBar(String message) {
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

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
