// services/collection_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';

class CollectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit user garbage submission (for Points page)
  Future<void> submitUserGarbage({
    required String userId,
    required String userName,
    required String garbageType,
    required double weight,
    required String email,
    required int pointsEarned,
  }) async {
    try {
      String submissionId = randomAlphaNumeric(10);
      DateTime now = DateTime.now();
      String formattedDate = _formatDate(now);

      Map<String, dynamic> submissionData = {
        "id": submissionId,
        "userId": userId,
        "userName": userName,
        "userEmail": email,
        "type": "user_submission",
        "garbageType": garbageType,
        "weight": weight,
        "pointsEarned": pointsEarned,
        "status": "completed",
        "submissionDate": formattedDate,
        "timestamp": FieldValue.serverTimestamp(),
        "collectionDate": FieldValue.serverTimestamp(),
      };

      // Create only in UserSubmissions collection
      await _firestore
          .collection("UserSubmissions")
          .doc(submissionId)
          .set(submissionData);

      // Also add to user's personal submissions
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("Submissions")
          .doc(submissionId)
          .set(submissionData);

      print("User submission created: $submissionId");
    } catch (e) {
      print("Error submitting user garbage: $e");
      throw e;
    }
  }

  // Start collection for unknown garbage (from Home page)
  Future<void> startUnknownCollection({
    required String userId,
    required String userName,
    required double weight,
    required String location,
    String? description,
  }) async {
    try {
      String collectionId = randomAlphaNumeric(10);
      DateTime now = DateTime.now();
      String formattedDate = _formatDate(now);

      Map<String, dynamic> collectionData = {
        "id": collectionId,
        "userId": userId,
        "userName": userName,
        "type": "unknown_collection",
        "garbageType": "Unknown",
        "weight": weight,
        "location": location,
        "description": description ?? "Unknown garbage collection",
        "status": "pending_identification",
        "pointsEarned": 0, // Will be updated after identification
        "collectionDate": formattedDate,
        "timestamp": FieldValue.serverTimestamp(),
        "requiresIdentification": true,
      };

      await _firestore
          .collection("Collections")
          .doc(collectionId)
          .set(collectionData);

      print("Unknown collection started: $collectionId");
    } catch (e) {
      print("Error starting unknown collection: $e");
      throw e;
    }
  }

  // Submit detected garbage type (from Home page categories)
  Future<void> submitDetectedGarbage({
    required String userId,
    required String userName,
    required String garbageType,
    required double weight,
    required String location,
    int? customPoints,
  }) async {
    try {
      String collectionId = randomAlphaNumeric(10);
      DateTime now = DateTime.now();
      String formattedDate = _formatDate(now);

      // Points calculation
      final pointsMap = {
        'Plastic': 5,
        'Paper': 3,
        'Glass': 7,
        'Metal': 10,
        'E-Waste': 15,
        'Organic': 2,
      };

      int pointsEarned =
          customPoints ?? (pointsMap[garbageType] ?? 3) * weight.toInt();

      Map<String, dynamic> collectionData = {
        "id": collectionId,
        "userId": userId,
        "userName": userName,
        "type": "detected_collection",
        "garbageType": garbageType,
        "weight": weight,
        "location": location,
        "pointsEarned": pointsEarned,
        "status": "completed",
        "collectionDate": formattedDate,
        "timestamp": FieldValue.serverTimestamp(),
        "requiresIdentification": false,
      };

      await _firestore
          .collection("Collections")
          .doc(collectionId)
          .set(collectionData);

      print("Detected garbage submitted: $collectionId");
    } catch (e) {
      print("Error submitting detected garbage: $e");
      throw e;
    }
  }

  // Update unknown collection with identified type
  Future<void> identifyUnknownCollection({
    required String collectionId,
    required String garbageType,
    required int pointsEarned,
  }) async {
    try {
      await _firestore.collection("Collections").doc(collectionId).update({
        "garbageType": garbageType,
        "pointsEarned": pointsEarned,
        "status": "completed",
        "identifiedAt": FieldValue.serverTimestamp(),
        "requiresIdentification": false,
      });

      print("Collection identified: $collectionId as $garbageType");
    } catch (e) {
      print("Error identifying collection: $e");
      throw e;
    }
  }

  // Get user submissions for Points page
  Stream<QuerySnapshot> getUserSubmissions(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("Submissions")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // Get collections for Home page
  Stream<QuerySnapshot> getUserCollections(String userId) {
    return _firestore
        .collection("Collections")
        .where("userId", isEqualTo: userId)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // Get pending identifications
  Stream<QuerySnapshot> getPendingIdentifications(String userId) {
    return _firestore
        .collection("Collections")
        .where("userId", isEqualTo: userId)
        .where("requiresIdentification", isEqualTo: true)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
