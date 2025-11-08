import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:recycleapp/pages/bottomnav.dart';
import 'package:recycleapp/services/database.dart';
import 'package:recycleapp/services/shared_pref.dart';

class AuthMethods {
  // Single instances of FirebaseAuth and GoogleSignIn
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Google Sign-In method
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // Trigger Google Sign-In
      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();
      if (googleSignInAccount == null) return; // User canceled the login

      //  Obtain auth details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleSignInAccount.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // Sign in with Firebase
      UserCredential result = await _firebaseAuth.signInWithCredential(
        credential,
      );
      User? userDetails = result.user;

      if (userDetails != null) {
        // Save user details in Shared Preferences
        await SharedpreferenceHelper().saveUserEmail(userDetails.email!);
        await SharedpreferenceHelper().saveUserId(userDetails.uid);
        await SharedpreferenceHelper().saveUserImage(
          userDetails.photoURL ?? '',
        );
        await SharedpreferenceHelper().saveUserName(
          userDetails.displayName ?? '',
        );

        // Add user info to Firestore database
        Map<String, dynamic> userInfoMap = {
          "email": userDetails.email,
          "name": userDetails.displayName,
          "image": userDetails.photoURL,
          "Id": userDetails.uid,
          "Points": "0",
        };
        await DatabaseMethods().addUserInfo(userInfoMap, userDetails.uid);

        //  Navigate to BottomNav page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BottomNav()),
        );
      }
    } catch (e) {
      print("Error signing in with Google: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error signing in: $e")));
    }
  }

  // Sign out method
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut(); // just signOut(), not disconnect()
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // Delete current user
  Future<void> deleteUser() async {
    try {
      User? user = _firebaseAuth.currentUser;
      await user?.delete();
      print("User deleted successfully");
    } catch (e) {
      print("Error deleting user: $e");
    }
  }
}
