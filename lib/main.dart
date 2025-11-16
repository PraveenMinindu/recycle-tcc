import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:recycleapp/Driver/bottomnav.dart';
import 'package:recycleapp/Driver/login.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'package:recycleapp/Admin/admin_login.dart';
//import 'package:recycleapp/Admin/admin_approval.dart';
//import 'package:recycleapp/Admin/admin_reedem.dart';
import 'package:recycleapp/Admin/home_admin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recycle App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home:
          AdminAuthCheck(), //  AuthCheck(), //HomeAdmin(), //AuthCheck(), //HomeAdmin(), // AuthCheck(), //HomeAdmin(), //AuthCheck(), //HomeAdmin(), //AuthCheck(), //HomeAdmin(), //AuthCheck(), //HomeAdmin(), //  AuthCheck(), // AdminLogin(), //HomeAdmin(), //AuthCheck(), //HomeAdmin(), //AuthCheck(), //AdminLogin(), AdminLogin(), //AuthCheck(), //AdminLogin(), //HomeAdmin(), //HomeAdmin(), //AdminReedem(), //AdminApproval(),AuthCheck(),
    );
  }
}

// Widget to check if user is already logged in
class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SharedpreferenceHelper().getUserId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return BottomNav();
        } else {
          return LogIn();
        }
      },
    );
  }
}

// Admin Authentication Check - FIXED VERSION
class AdminAuthCheck extends StatelessWidget {
  const AdminAuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SharedpreferenceHelper().getUserId(),
      builder: (context, snapshot) {
        print('=== AdminAuthCheck Debug ===');
        print('Connection state: ${snapshot.connectionState}');
        print('Has data: ${snapshot.hasData}');
        print('User ID: "${snapshot.data}"');
        print('===========================');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Checking admin authentication...'),
                ],
              ),
            ),
          );
        }

        // For now, always show admin login
        print('Navigating to Admin Login');
        return const AdminLogin();
      },
    );
  }
}
