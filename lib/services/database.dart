import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';

class DatabaseMethods {
  // User Management
  Future addUserInfo(Map<String, dynamic> userInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("Truck_Drivers")
        .doc(id)
        .set(userInfoMap);
  }

  // Item Upload Methods with Base64 Support
  Future addUserUploadItem(
    Map<String, dynamic> userInfoMap,
    String id,
    String itemid,
  ) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Items")
        .doc(itemid)
        .set(userInfoMap);
  }

  Future addAdminItem(Map<String, dynamic> userInfoMap, String id) async {
    return await FirebaseFirestore.instance
        .collection("Requests")
        .doc(id)
        .set(userInfoMap);
  }

  // Approval System
  Future<Stream<QuerySnapshot>> getAdminApproval() async {
    return await FirebaseFirestore.instance
        .collection("Requests")
        .where("Status", isEqualTo: "Pending")
        .snapshots();
  }

  Future<Stream<QuerySnapshot>> getUserPendingRequests(String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Items")
        .where("Status", isEqualTo: "Pending")
        .snapshots();
  }

  Future<Stream<QuerySnapshot>> getAdminReedemApproval() async {
    return await FirebaseFirestore.instance
        .collection("Reedem")
        .where("Status", isEqualTo: "Pending")
        .snapshots();
  }

  Future<Stream<QuerySnapshot>> getUserTransactions(String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Reedem")
        .snapshots();
  }

  // Request Management
  Future updateAdminRequest(String id) async {
    return await FirebaseFirestore.instance
        .collection("Requests")
        .doc(id)
        .update({"Status": "Approved"});
  }

  Future<void> deleteAdminRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection("Requests")
          .doc(requestId)
          .delete();
    } catch (e) {
      print("Error deleting admin request: $e");
      throw e;
    }
  }

  Future updateUserRequest(String id, String itemid) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Items")
        .doc(itemid)
        .update({"Status": "Approved"});
  }

  // Redeem System
  Future updateAdminReedemRequest(String id) async {
    return await FirebaseFirestore.instance.collection("Reedem").doc(id).update(
      {"Status": "Approved"},
    );
  }

  Future updateUserReedemRequest(String id, String itemid) async {
    return await FirebaseFirestore.instance
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
    return await FirebaseFirestore.instance
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
    return await FirebaseFirestore.instance
        .collection("Reedem")
        .doc(reedemid)
        .set(userInfoMap);
  }

  // Points System
  Future updateUserPoints(String id, String points) async {
    return await FirebaseFirestore.instance.collection("users").doc(id).update({
      "Points": points,
    });
  }

  // Enhanced Points System
  Future addGarbageSubmission(
    Map<String, dynamic> submissionMap,
    String userId,
    String submissionId,
  ) async {
    // Add to user's submissions
    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("Submissions")
        .doc(submissionId)
        .set(submissionMap);

    // Also add to admin approval queue
    return await FirebaseFirestore.instance
        .collection("GarbageSubmissions")
        .doc(submissionId)
        .set(submissionMap);
  }

  // NEW: Get garbage submissions for admin approval
  Future<Stream<QuerySnapshot>> getGarbageSubmissionsAdmin() async {
    return await FirebaseFirestore.instance
        .collection("GarbageSubmissions")
        .where("Status", isEqualTo: "Pending")
        .snapshots();
  }

  // NEW: Update garbage submission status (admin approval)
  Future updateGarbageSubmissionStatus(
    String submissionId,
    String status,
  ) async {
    // Update in admin collection
    await FirebaseFirestore.instance
        .collection("GarbageSubmissions")
        .doc(submissionId)
        .update({"Status": status});

    // Also update in user's collection
    var submissionDoc =
        await FirebaseFirestore.instance
            .collection("GarbageSubmissions")
            .doc(submissionId)
            .get();

    if (submissionDoc.exists) {
      String userId = submissionDoc["UserId"];
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("Submissions")
          .doc(submissionId)
          .update({"Status": status});
    }
  }

  // Voucher System
  Future<Stream<QuerySnapshot>> getAvailableVouchers() async {
    return await FirebaseFirestore.instance
        .collection("Vouchers")
        .where("Active", isEqualTo: true)
        .snapshots();
  }

  Future addUserVoucher(String userId, Map<String, dynamic> voucherMap) async {
    String voucherId = randomAlphaNumeric(10);
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("RedeemedVouchers")
        .doc(voucherId)
        .set(voucherMap);
  }

  // Get user's garbage submissions
  Future<Stream<QuerySnapshot>> getUserSubmissions(String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Submissions")
        .snapshots();
  }

  // Get user's pending requests by category
  Future<Stream<QuerySnapshot>> getUserPendingRequestsByCategory(
    String id,
    String category,
  ) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Items")
        .where("Status", isEqualTo: "Pending")
        .where("Category", isEqualTo: category)
        .snapshots();
  }

  // Get user's redeemed vouchers
  Future<Stream<QuerySnapshot>> getUserRedeemedVouchers(String id) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("RedeemedVouchers")
        .snapshots();
  }

  // Get all user transactions
  Future<Stream<QuerySnapshot>> getUserAllTransactions(String id) async {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .collection("Submissions")
        .snapshots();
  }

  // NEW: Get user info
  Future<DocumentSnapshot> getUserInfo(String userId) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .get();
  }

  // NEW: Get user points
  Future<String> getUserPoints(String userId) async {
    try {
      DocumentSnapshot userDoc = await getUserInfo(userId);
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        return data['Points']?.toString() ?? '0';
      }
      return '0';
    } catch (e) {
      print('Error getting user points: $e');
      return '0';
    }
  }

  // NEW: Add points to user
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

  // NEW: Subtract points from user (for redeeming)
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

  // NEW: Get items by status
  Future<Stream<QuerySnapshot>> getUserItemsByStatus(
    String userId,
    String status,
  ) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("Items")
        .where("Status", isEqualTo: status)
        .snapshots();
  }

  // NEW: Get approved items for user
  Future<Stream<QuerySnapshot>> getUserApprovedItems(String userId) async {
    return await getUserItemsByStatus(userId, "Approved");
  }

  // NEW: Get rejected items for user
  Future<Stream<QuerySnapshot>> getUserRejectedItems(String userId) async {
    return await getUserItemsByStatus(userId, "Rejected");
  }

  // NEW: Delete user item
  Future<void> deleteUserItem(String userId, String itemId) async {
    try {
      await FirebaseFirestore.instance
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

  // NEW: Update item information
  Future updateItemInfo(
    String userId,
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("Items")
        .doc(itemId)
        .update(updates);
  }

  // NEW: Get all users (for admin)
  Future<Stream<QuerySnapshot>> getAllUsers() async {
    return await FirebaseFirestore.instance.collection("users").snapshots();
  }

  // NEW: Get truck drivers (for admin)
  Future<Stream<QuerySnapshot>> getAllTruckDrivers() async {
    return await FirebaseFirestore.instance
        .collection("Truck_Drivers")
        .snapshots();
  }

  // NEW: Get statistics for dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get pending requests count
      var pendingRequests =
          await FirebaseFirestore.instance
              .collection("Requests")
              .where("Status", isEqualTo: "Pending")
              .get();

      // Get total users count
      var totalUsers =
          await FirebaseFirestore.instance.collection("users").get();

      // Get total submissions count
      var totalSubmissions =
          await FirebaseFirestore.instance
              .collection("GarbageSubmissions")
              .get();

      // Get pending redeem requests count
      var pendingRedeems =
          await FirebaseFirestore.instance
              .collection("Reedem")
              .where("Status", isEqualTo: "Pending")
              .get();

      return {
        'pendingRequests': pendingRequests.docs.length,
        'totalUsers': totalUsers.docs.length,
        'totalSubmissions': totalSubmissions.docs.length,
        'pendingRedeems': pendingRedeems.docs.length,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'pendingRequests': 0,
        'totalUsers': 0,
        'totalSubmissions': 0,
        'pendingRedeems': 0,
      };
    }
  }

  // NEW: Search items by category or name
  Future<Stream<QuerySnapshot>> searchItems(
    String userId,
    String searchTerm,
  ) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("Items")
        .where("Category", isGreaterThanOrEqualTo: searchTerm)
        .where("Category", isLessThan: searchTerm + 'z')
        .snapshots();
  }

  // NEW: Bulk operations for admin
  Future<void> bulkApproveRequests(List<String> requestIds) async {
    final batch = FirebaseFirestore.instance.batch();

    for (String requestId in requestIds) {
      var docRef = FirebaseFirestore.instance
          .collection("Requests")
          .doc(requestId);
      batch.update(docRef, {"Status": "Approved"});
    }

    await batch.commit();
  }

  // NEW: Get user activity log
  Future<Stream<QuerySnapshot>> getUserActivityLog(String userId) async {
    return await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("ActivityLog")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // NEW: Add activity log entry
  Future addActivityLog(String userId, String action, String details) async {
    String logId = randomAlphaNumeric(10);
    return await FirebaseFirestore.instance
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
}
