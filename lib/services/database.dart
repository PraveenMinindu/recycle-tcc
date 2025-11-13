// services/database.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:random_string/random_string.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class DatabaseService {
  final String uid;

  DatabaseService({required this.uid});

  final CollectionReference userCollection = FirebaseFirestore.instance
      .collection('users');

  // User management methods
  Future updateUserData({
    required String email,
    required String name,
    required int coins,
    String? photoUrl,
    String provider = 'email',
    bool isEmailVerified = false,
  }) async {
    return await userCollection.doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'coins': coins,
      'Points': coins.toString(),
      'photoUrl': photoUrl,
      'provider': provider,
      'isEmailVerified': isEmailVerified,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future updateLastLogin() async {
    return await userCollection.doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot> getUserData() async {
    return await userCollection.doc(uid).get();
  }

  Future updateUserCoins(int coins) async {
    return await userCollection.doc(uid).set({
      'coins': coins,
      'Points': coins.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future addUserCoins(int coinsToAdd) async {
    final userDoc = await getUserData();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final currentCoins = data['coins'] ?? 0;
      return await updateUserCoins(currentCoins + coinsToAdd);
    }
    return await updateUserCoins(coinsToAdd);
  }

  Future subtractUserCoins(int coinsToSubtract) async {
    final userDoc = await getUserData();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final currentCoins = data['coins'] ?? 0;
      if (currentCoins >= coinsToSubtract) {
        return await updateUserCoins(currentCoins - coinsToSubtract);
      } else {
        throw Exception("Insufficient coins");
      }
    }
    throw Exception("User not found");
  }

  Future updateUserProfile({String? name, String? photoUrl}) async {
    Map<String, dynamic> updates = {'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    return await userCollection.doc(uid).update(updates);
  }

  // Profile management methods
  Future updateUserProfileData({
    required String name,
    required String email,
    String? phone,
    String? address,
    String? photoUrl,
  }) async {
    return await userCollection.doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone ?? '',
      'address': address ?? '',
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfileData() async {
    try {
      DocumentSnapshot userDoc = await userCollection.doc(uid).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user profile data: $e');
      return null;
    }
  }

  Future updateUserContactInfo({String? phone, String? address}) async {
    Map<String, dynamic> updates = {'updatedAt': FieldValue.serverTimestamp()};

    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;

    return await userCollection.doc(uid).update(updates);
  }
}

class DatabaseMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ========== TOTAL COLLECTION TRACKING METHODS ==========

  // NEW: Update total daily collection
  Future<void> updateTotalCollection(double weight, String garbageType) async {
    try {
      DateTime now = DateTime.now();
      String todayKey = "${now.day}-${now.month}-${now.year}";

      // Get or create today's collection document
      DocumentReference todayDoc = _firestore
          .collection("TotalCollections")
          .doc(todayKey);

      DocumentSnapshot snapshot = await todayDoc.get();

      if (snapshot.exists) {
        // Update existing document
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        double currentTotal = (data['totalWeight'] ?? 0).toDouble();
        int currentCount = (data['totalCollections'] ?? 0) as int;

        // Update garbage type breakdown
        Map<String, dynamic> typeBreakdown = Map<String, dynamic>.from(
          data['typeBreakdown'] ?? {},
        );
        double typeCurrent = (typeBreakdown[garbageType] ?? 0).toDouble();
        typeBreakdown[garbageType] = typeCurrent + weight;

        await todayDoc.update({
          'totalWeight': currentTotal + weight,
          'totalCollections': currentCount + 1,
          'typeBreakdown': typeBreakdown,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new document for today
        Map<String, dynamic> typeBreakdown = {garbageType: weight};

        await todayDoc.set({
          'date': todayKey,
          'totalWeight': weight,
          'totalCollections': 1,
          'typeBreakdown': typeBreakdown,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      print(
        "Updated total collection for $todayKey: +$weight kg of $garbageType",
      );
    } catch (e) {
      print('Error updating total collection: $e');
      throw e;
    }
  }

  // NEW: Get today's total collection
  Future<Map<String, dynamic>> getTodayCollection() async {
    try {
      DateTime now = DateTime.now();
      String todayKey = "${now.day}-${now.month}-${now.year}";

      DocumentSnapshot snapshot =
          await _firestore.collection("TotalCollections").doc(todayKey).get();

      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      } else {
        return {
          'date': todayKey,
          'totalWeight': 0,
          'totalCollections': 0,
          'typeBreakdown': {},
        };
      }
    } catch (e) {
      print('Error getting today collection: $e');
      return {'totalWeight': 0, 'totalCollections': 0, 'typeBreakdown': {}};
    }
  }

  // NEW: Get total waste collected (both user submissions and approved driver collections)
  Future<Map<String, dynamic>> getTotalWasteCollected() async {
    try {
      DateTime now = DateTime.now();
      String todayKey = "${now.day}-${now.month}-${now.year}";

      // Get today's total from TotalCollections
      DocumentSnapshot todayDoc =
          await _firestore.collection("TotalCollections").doc(todayKey).get();

      double todayWeight = 0;
      int todayCollections = 0;
      Map<String, dynamic> typeBreakdown = {};

      if (todayDoc.exists) {
        var data = todayDoc.data() as Map<String, dynamic>;
        todayWeight = (data['totalWeight'] ?? 0).toDouble();
        todayCollections = (data['totalCollections'] ?? 0) as int;
        typeBreakdown = data['typeBreakdown'] ?? {};
      }

      return {
        'todayWeight': todayWeight,
        'todayCollections': todayCollections,
        'typeBreakdown': typeBreakdown,
        'date': todayKey,
      };
    } catch (e) {
      print('Error getting total waste collected: $e');
      return {
        'todayWeight': 0,
        'todayCollections': 0,
        'typeBreakdown': {},
        'date': 'Error',
      };
    }
  }

  // NEW: Stream for real-time total waste updates
  Stream<DocumentSnapshot> getTotalWasteStream() {
    DateTime now = DateTime.now();
    String todayKey = "${now.day}-${now.month}-${now.year}";

    return _firestore.collection("TotalCollections").doc(todayKey).snapshots();
  }

  // NEW: Get all-time total waste collected
  Future<Map<String, dynamic>> getAllTimeTotalWaste() async {
    try {
      var collections = await _firestore.collection("TotalCollections").get();

      double totalWeight = 0;
      int totalCollections = 0;

      for (var doc in collections.docs) {
        var data = doc.data() as Map<String, dynamic>;
        totalWeight += (data['totalWeight'] ?? 0).toDouble();
        totalCollections += (data['totalCollections'] ?? 0) as int;
      }

      return {
        'allTimeWeight': totalWeight,
        'allTimeCollections': totalCollections,
      };
    } catch (e) {
      print('Error getting all-time waste: $e');
      return {'allTimeWeight': 0, 'allTimeCollections': 0};
    }
  }

  // NEW: Enhanced approve request method that includes collection tracking
  Future updateAdminRequest(
    String id, {
    Map<String, dynamic>? requestData,
  }) async {
    try {
      // Update the request status
      await _firestore.collection("Requests").doc(id).update({
        "Status": "Approved",
      });

      // If request data is provided, update total collection
      if (requestData != null) {
        await approveRequestWithCollection(id, requestData);
      }

      return true;
    } catch (e) {
      print('Error in updateAdminRequest: $e');
      throw e;
    }
  }

  // NEW: Enhanced approve request with total collection tracking
  Future<void> approveRequestWithCollection(
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      String garbageType = requestData["wasteType"] ?? "Unknown";
      double weight = (requestData["quantity"] ?? 0).toDouble();

      // Update total collection
      await updateTotalCollection(weight, garbageType);

      print(
        "Approved request $requestId added to total collection: $weight kg of $garbageType",
      );
    } catch (e) {
      print('Error in approveRequestWithCollection: $e');
      throw e;
    }
  }

  // ========== COMPLAINT MANAGEMENT METHODS ==========
  Stream<QuerySnapshot> getUserComplaints(String userId) {
    return _firestore
        .collection("complaints")
        .where("userId", isEqualTo: userId)
        .where("type", isEqualTo: "user")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Future submitUserComplaint(Map<String, dynamic> complaintMap) async {
    try {
      return await submitComplaint(complaintMap);
    } catch (e) {
      print('Error submitting user complaint: $e');
      throw e;
    }
  }

  Future submitComplaint(Map<String, dynamic> complaintMap) async {
    try {
      String complaintId = randomAlphaNumeric(10);
      complaintMap['id'] = complaintId;
      complaintMap['createdAt'] = FieldValue.serverTimestamp();
      complaintMap['updatedAt'] = FieldValue.serverTimestamp();

      return await _firestore
          .collection("complaints")
          .doc(complaintId)
          .set(complaintMap);
    } catch (e) {
      print('Error submitting complaint: $e');
      throw e;
    }
  }

  Future<List<String>> uploadComplaintImages(
    List<XFile> images,
    String complaintId,
  ) async {
    try {
      List<String> imageUrls = [];

      for (int i = 0; i < images.length; i++) {
        String fileName =
            'complaint_${complaintId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        Reference storageRef = _storage.ref().child(
          'complaint_images/$fileName',
        );

        UploadTask uploadTask = storageRef.putFile(File(images[i].path));
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      return imageUrls;
    } catch (e) {
      print('Error uploading images: $e');
      throw e;
    }
  }

  Stream<QuerySnapshot> getComplaintsByUserType(
    String userId,
    String userType,
  ) {
    if (userType == 'user') {
      return _firestore
          .collection("complaints")
          .where("userId", isEqualTo: userId)
          .where("type", isEqualTo: "user")
          .orderBy("createdAt", descending: true)
          .snapshots();
    } else {
      return _firestore
          .collection("complaints")
          .where("driverId", isEqualTo: userId)
          .where("type", isEqualTo: "driver")
          .orderBy("createdAt", descending: true)
          .snapshots();
    }
  }

  Stream<QuerySnapshot> getAllComplaints() {
    return _firestore
        .collection("complaints")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getComplaintsByType(String type) {
    return _firestore
        .collection("complaints")
        .where("type", isEqualTo: type)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getComplaintsByStatus(String status) {
    return _firestore
        .collection("complaints")
        .where("status", isEqualTo: status)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  Future updateComplaintStatus(
    String complaintId,
    String status, {
    String? adminNotes,
  }) async {
    try {
      Map<String, dynamic> updates = {
        "status": status,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      if (adminNotes != null) {
        updates["adminNotes"] = adminNotes;
      }

      if (status == "resolved") {
        updates["resolvedAt"] = FieldValue.serverTimestamp();
      }

      return await _firestore
          .collection("complaints")
          .doc(complaintId)
          .update(updates);
    } catch (e) {
      print('Error updating complaint status: $e');
      throw e;
    }
  }

  Future<void> deleteComplaint(String complaintId) async {
    try {
      await _firestore.collection("complaints").doc(complaintId).delete();
    } catch (e) {
      print("Error deleting complaint: $e");
      throw e;
    }
  }

  Future<Map<String, int>> getComplaintStats() async {
    try {
      final complaints = await _firestore.collection("complaints").get();

      int total = complaints.size;
      int pending =
          complaints.docs.where((doc) => doc["status"] == "pending").length;
      int inProgress =
          complaints.docs.where((doc) => doc["status"] == "in_progress").length;
      int resolved =
          complaints.docs.where((doc) => doc["status"] == "resolved").length;
      int userComplaints =
          complaints.docs.where((doc) => doc["type"] == "user").length;
      int driverComplaints =
          complaints.docs.where((doc) => doc["type"] == "driver").length;

      return {
        'total': total,
        'pending': pending,
        'inProgress': inProgress,
        'resolved': resolved,
        'userComplaints': userComplaints,
        'driverComplaints': driverComplaints,
      };
    } catch (e) {
      print('Error getting complaint stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'inProgress': 0,
        'resolved': 0,
        'userComplaints': 0,
        'driverComplaints': 0,
      };
    }
  }

  Map<String, dynamic> createUserComplaintData({
    required String userId,
    required String userEmail,
    required String userName,
    required String category,
    required String details,
    List<String> imageUrls = const [],
    String location = 'User Location',
  }) {
    return {
      'type': 'user',
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'category': category,
      'details': details,
      'imageUrls': imageUrls,
      'location': location,
      'priority': _getUserPriorityLevel(category),
      'status': 'pending',
    };
  }

  Map<String, dynamic> createDriverComplaintData({
    required String driverId,
    required String driverName,
    required String category,
    required String title,
    required String description,
    required String truckLicensePlate,
    required String location,
    required String priority,
    List<String> imageUrls = const [],
  }) {
    return {
      'type': 'driver',
      'driverId': driverId,
      'driverName': driverName,
      'category': category,
      'title': title,
      'description': description,
      'truckLicensePlate': truckLicensePlate,
      'location': location,
      'priority': priority.toLowerCase(),
      'imageUrls': imageUrls,
      'status': 'pending',
    };
  }

  String _getUserPriorityLevel(String category) {
    switch (category.toLowerCase()) {
      case 'emergency':
      case 'accident':
      case 'breakdown':
        return 'high';
      case 'truck':
      case 'bin':
        return 'medium';
      default:
        return 'low';
    }
  }

  // ========== USER SUBMISSIONS & COLLECTIONS ==========

  // UPGRADED: Submit user garbage with total collection tracking
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
      String formattedDate = "${now.day}/${now.month}/${now.year}";

      Map<String, dynamic> submissionData = {
        "id": submissionId,
        "userId": userId,
        "DriverName": userName,
        "userEmail": email,
        "type": "user_submission",
        "garbageType": garbageType,
        "weight": weight,
        "pointsEarned": pointsEarned,
        "status": "completed",
        "submissionDate": formattedDate,
        "timestamp": FieldValue.serverTimestamp(),
        "collectionDate": FieldValue.serverTimestamp(),
        "source": "points_page", // NEW: Track source
      };

      // Create in UserSubmissions collection
      await _firestore
          .collection("UserSubmissions")
          .doc(submissionId)
          .set(submissionData);

      // Add to user's personal submissions for history
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("Submissions")
          .doc(submissionId)
          .set(submissionData);

      // NEW: Update total collection
      await updateTotalCollection(weight, garbageType);

      print("User submission created: $submissionId");
    } catch (e) {
      print("Error submitting user garbage: $e");
      throw e;
    }
  }

  // UPGRADED: Start collection with total tracking
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
      String formattedDate = "${now.day}/${now.month}/${now.year}";

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
        "pointsEarned": 0,
        "collectionDate": formattedDate,
        "timestamp": FieldValue.serverTimestamp(),
        "requiresIdentification": true,
        "source": "home_page", // NEW: Track source
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

  // UPGRADED: Submit detected garbage with total tracking
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
      String formattedDate = "${now.day}/${now.month}/${now.year}";

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
        "source": "home_page", // NEW: Track source
      };

      await _firestore
          .collection("Collections")
          .doc(collectionId)
          .set(collectionData);

      // NEW: Update total collection for detected garbage
      await updateTotalCollection(weight, garbageType);

      print("Detected garbage submitted: $collectionId");
    } catch (e) {
      print("Error submitting detected garbage: $e");
      throw e;
    }
  }

  // NEW: Get user submissions for Points page
  Stream<QuerySnapshot> getUserSubmissions(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("Submissions")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // NEW: Get collections for Home page
  Stream<QuerySnapshot> getUserCollections(String userId) {
    return _firestore
        .collection("Collections")
        .where("userId", isEqualTo: userId)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // NEW: Get pending identifications
  Stream<QuerySnapshot> getPendingIdentifications(String userId) {
    return _firestore
        .collection("Collections")
        .where("userId", isEqualTo: userId)
        .where("requiresIdentification", isEqualTo: true)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // ========== LEGACY METHODS (KEEP FOR BACKWARD COMPATIBILITY) ==========

  Future addUserInfo(Map<String, dynamic> userInfoMap, String id) async {
    return await _firestore
        .collection("Truck_Drivers")
        .doc(id)
        .set(userInfoMap);
  }

  Future addUserUploadItem(
    Map<String, dynamic> userInfoMap,
    String id,
    String itemid,
  ) async {
    return await _firestore
        .collection("users")
        .doc(id)
        .collection("Items")
        .doc(itemid)
        .set(userInfoMap);
  }

  Future addAdminItem(Map<String, dynamic> userInfoMap, String id) async {
    return await _firestore.collection("Requests").doc(id).set(userInfoMap);
  }

  Stream<QuerySnapshot> getAdminApproval() {
    return _firestore
        .collection("Requests")
        .where("Status", isEqualTo: "Pending")
        .snapshots();
  }

  Stream<QuerySnapshot> getUserPendingRequests(String id) {
    return _firestore
        .collection("users")
        .doc(id)
        .collection("Items")
        .where("Status", isEqualTo: "Pending")
        .snapshots();
  }

  Stream<QuerySnapshot> getAdminReedemApproval() {
    return _firestore
        .collection("Reedem")
        .where("Status", isEqualTo: "Pending")
        .snapshots();
  }

  Stream<QuerySnapshot> getUserTransactions(String id) {
    return _firestore
        .collection("users")
        .doc(id)
        .collection("Reedem")
        .snapshots();
  }

  // Keep old method for backward compatibility
  Future updateAdminRequestOld(String id) async {
    return await _firestore.collection("Requests").doc(id).update({
      "Status": "Approved",
    });
  }

  Future<void> deleteAdminRequest(String requestId) async {
    try {
      await _firestore.collection("Requests").doc(requestId).delete();
    } catch (e) {
      print("Error deleting admin request: $e");
      throw e;
    }
  }

  Future updateUserRequest(String id, String itemid) async {
    return await _firestore
        .collection("users")
        .doc(id)
        .collection("Items")
        .doc(itemid)
        .update({"Status": "Approved"});
  }

  Future updateAdminReedemRequest(String id) async {
    return await _firestore.collection("Reedem").doc(id).update({
      "Status": "Approved",
    });
  }

  Future updateUserReedemRequest(String id, String itemid) async {
    return await _firestore
        .collection("users")
        .doc(id)
        .collection("Reedem")
        .doc(itemid)
        .update({"Status": "Approved"});
  }

  Future addUserReedemPoints(
    Map<String, dynamic> userInfoMap,
    String id,
    String reedemid,
  ) async {
    return await _firestore
        .collection("users")
        .doc(id)
        .collection("Reedem")
        .doc(reedemid)
        .set(userInfoMap);
  }

  Future addAdminReedemRequests(
    Map<String, dynamic> userInfoMap,
    String reedemid,
  ) async {
    return await _firestore.collection("Reedem").doc(reedemid).set(userInfoMap);
  }

  // UPDATED: Legacy garbage submission - NOW ONLY CREATES ONE COLLECTION
  Future addGarbageSubmission(
    Map<String, dynamic> submissionMap,
    String userId,
    String submissionId,
  ) async {
    try {
      // Only create in UserSubmissions collection (no duplicate)
      await _firestore
          .collection("UserSubmissions")
          .doc(submissionId)
          .set(submissionMap);

      // Also add to user's personal submissions
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("Submissions")
          .doc(submissionId)
          .set(submissionMap);

      print("Garbage submission added to UserSubmissions: $submissionId");
    } catch (e) {
      print("Error adding garbage submission: $e");
      throw e;
    }
  }

  Stream<QuerySnapshot> getGarbageSubmissionsAdmin() {
    return _firestore
        .collection("UserSubmissions")
        .where("status", isEqualTo: "pending")
        .snapshots();
  }

  Future updateGarbageSubmissionStatus(
    String submissionId,
    String status,
  ) async {
    try {
      await _firestore.collection("UserSubmissions").doc(submissionId).update({
        "status": status,
      });

      // Also update in user's personal submissions if needed
      var submissionDoc =
          await _firestore
              .collection("UserSubmissions")
              .doc(submissionId)
              .get();

      if (submissionDoc.exists) {
        String userId = submissionDoc["userId"];
        await _firestore
            .collection("users")
            .doc(userId)
            .collection("Submissions")
            .doc(submissionId)
            .update({"status": status});
      }
    } catch (e) {
      print("Error updating garbage submission status: $e");
      throw e;
    }
  }

  // ========== USER POINTS & PROFILE MANAGEMENT ==========
  Future updateUserPoints(String id, String points) async {
    try {
      return await _firestore.collection("users").doc(id).set({
        "Points": points,
        "coins": int.tryParse(points) ?? 0,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating user points: $e");
      throw e;
    }
  }

  // NEW: Direct points update method
  Future<void> updateUserPointsDirect(String userId, String points) async {
    try {
      await _firestore.collection("users").doc(userId).set({
        "Points": points,
        "coins": int.tryParse(points) ?? 0,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating user points directly: $e");
      throw e;
    }
  }

  Future<DocumentSnapshot> getUserInfo(String userId) async {
    return await _firestore.collection("users").doc(userId).get();
  }

  Future<String> getUserPoints(String userId) async {
    try {
      DocumentSnapshot userDoc = await getUserInfo(userId);
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        var points = data['Points'] ?? data['coins'] ?? '0';
        return points.toString();
      } else {
        await _firestore.collection("users").doc(userId).set({
          'Points': '0',
          'coins': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return '0';
      }
    } catch (e) {
      print('Error getting user points: $e');
      return '0';
    }
  }

  Future addUserPoints(String userId, int pointsToAdd) async {
    try {
      String currentPoints = await getUserPoints(userId);
      int updatedPoints = int.parse(currentPoints) + pointsToAdd;
      return await updateUserPoints(userId, updatedPoints.toString());
    } catch (e) {
      print('Error adding user points: $e');
      throw e;
    }
  }

  Future subtractUserPoints(String userId, int pointsToSubtract) async {
    try {
      String currentPoints = await getUserPoints(userId);
      int current = int.parse(currentPoints);
      if (current < pointsToSubtract) {
        throw Exception("Insufficient points");
      }
      int updatedPoints = current - pointsToSubtract;
      return await updateUserPoints(userId, updatedPoints.toString());
    } catch (e) {
      print('Error subtracting user points: $e');
      throw e;
    }
  }

  // ========== VOUCHER MANAGEMENT ==========
  Stream<QuerySnapshot> getAvailableVouchers() {
    return _firestore
        .collection("Vouchers")
        .where("Active", isEqualTo: true)
        .snapshots();
  }

  Future addUserVoucher(String userId, Map<String, dynamic> voucherMap) async {
    String voucherId = randomAlphaNumeric(10);
    return await _firestore
        .collection("users")
        .doc(userId)
        .collection("RedeemedVouchers")
        .doc(voucherId)
        .set(voucherMap);
  }

  Stream<QuerySnapshot> getUserRedeemedVouchers(String id) {
    return _firestore
        .collection("users")
        .doc(id)
        .collection("RedeemedVouchers")
        .snapshots();
  }

  // ========== ADDITIONAL USER METHODS ==========
  Stream<QuerySnapshot> getUserItemsByStatus(String userId, String status) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("Items")
        .where("Status", isEqualTo: status)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserApprovedItems(String userId) {
    return getUserItemsByStatus(userId, "Approved");
  }

  Stream<QuerySnapshot> getUserRejectedItems(String userId) {
    return getUserItemsByStatus(userId, "Rejected");
  }

  Future<void> deleteUserItem(String userId, String itemId) async {
    try {
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("Items")
          .doc(itemId)
          .delete();
    } catch (e) {
      print("Error deleting user item: $e");
      throw e;
    }
  }

  Future updateItemInfo(
    String userId,
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    return await _firestore
        .collection("users")
        .doc(userId)
        .collection("Items")
        .doc(itemId)
        .update(updates);
  }

  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection("users").snapshots();
  }

  Stream<QuerySnapshot> getAllTruckDrivers() {
    return _firestore.collection("Truck_Drivers").snapshots();
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      var pendingRequests =
          await _firestore
              .collection("Requests")
              .where("Status", isEqualTo: "Pending")
              .get();
      var totalUsers = await _firestore.collection("users").get();
      var totalSubmissions =
          await _firestore.collection("UserSubmissions").get();
      var pendingRedeems =
          await _firestore
              .collection("Reedem")
              .where("Status", isEqualTo: "Pending")
              .get();
      var complaintStats = await getComplaintStats();
      var totalWaste = await getTotalWasteCollected();

      return {
        'pendingRequests': pendingRequests.docs.length,
        'totalUsers': totalUsers.docs.length,
        'totalSubmissions': totalSubmissions.docs.length,
        'pendingRedeems': pendingRedeems.docs.length,
        'pendingComplaints': complaintStats['pending'] ?? 0,
        'totalComplaints': complaintStats['total'] ?? 0,
        'todayWeight': totalWaste['todayWeight'] ?? 0,
        'todayCollections': totalWaste['todayCollections'] ?? 0,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'pendingRequests': 0,
        'totalUsers': 0,
        'totalSubmissions': 0,
        'pendingRedeems': 0,
        'pendingComplaints': 0,
        'totalComplaints': 0,
        'todayWeight': 0,
        'todayCollections': 0,
      };
    }
  }

  Stream<QuerySnapshot> searchItems(String userId, String searchTerm) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("Items")
        .where("Category", isGreaterThanOrEqualTo: searchTerm)
        .where("Category", isLessThan: searchTerm + 'z')
        .snapshots();
  }

  Future<void> bulkApproveRequests(List<String> requestIds) async {
    final batch = _firestore.batch();
    for (String requestId in requestIds) {
      var docRef = _firestore.collection("Requests").doc(requestId);
      batch.update(docRef, {"Status": "Approved"});
    }
    await batch.commit();
  }

  Stream<QuerySnapshot> getUserActivityLog(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("ActivityLog")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  Future addActivityLog(String userId, String action, String details) async {
    String logId = randomAlphaNumeric(10);
    return await _firestore
        .collection("users")
        .doc(userId)
        .collection("ActivityLog")
        .doc(logId)
        .set({
          "action": action,
          "details": details,
          "timestamp": FieldValue.serverTimestamp(),
        });
  }

  Future ensureUserExists(
    String userId, {
    String? userName,
    String? email,
  }) async {
    try {
      DocumentSnapshot userDoc = await getUserInfo(userId);
      if (!userDoc.exists) {
        await _firestore.collection("users").doc(userId).set({
          'Points': '0',
          'coins': 0,
          'Name': userName ?? 'Unknown User',
          'Email': email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print("Created user document for: $userId");
      }
    } catch (e) {
      print("Error ensuring user exists: $e");
      throw e;
    }
  }

  Stream<QuerySnapshot> getUserSubmissionsPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    var query = _firestore
        .collection("users")
        .doc(userId)
        .collection("Submissions")
        .orderBy("timestamp", descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.snapshots();
  }

  Future<int> getTotalPointsEarned(String userId) async {
    try {
      var submissions =
          await _firestore
              .collection("users")
              .doc(userId)
              .collection("Submissions")
              .get();
      int total = 0;
      for (var doc in submissions.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data["pointsEarned"] != null) {
          total += int.tryParse(data["pointsEarned"].toString()) ?? 0;
        }
      }
      return total;
    } catch (e) {
      print('Error getting total points earned: $e');
      return 0;
    }
  }

  Stream<QuerySnapshot> getUserPendingRequestsByCategory(
    String id,
    String category,
  ) {
    return _firestore
        .collection("users")
        .doc(id)
        .collection("Items")
        .where("Status", isEqualTo: "Pending")
        .where("Category", isEqualTo: category)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserAllTransactions(String id) {
    return _firestore
        .collection("users")
        .doc(id)
        .collection("Submissions")
        .snapshots();
  }
}
