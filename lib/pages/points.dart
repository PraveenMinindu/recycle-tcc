import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:random_string/random_string.dart';
import 'package:recycleapp/services/database.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'package:recycleapp/services/widget_support.dart';

class Points extends StatefulWidget {
  const Points({super.key});

  @override
  State<Points> createState() => _PointsState();
}

class _PointsState extends State<Points> {
  String? id, mypoints, name;
  Stream? pointsStream;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // ADDED

  getthesharedpref() async {
    id = await SharedpreferenceHelper().getUserId();
    name = await SharedpreferenceHelper().getUserName();
    setState(() {});
  }

  ontheload() async {
    await getthesharedpref();
    mypoints = await getUserPoints(id!);
    pointsStream = await DatabaseMethods().getUserSubmissions(id!);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ontheload();
  }

  TextEditingController weightController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  String selectedGarbageType = 'Plastic';

  Map<String, int> garbageTypePoints = {
    'Plastic': 5,
    'Paper': 3,
    'Glass': 7,
    'Metal': 10,
    'E-Waste': 15,
    'Organic': 2,
  };

  Future<String> getUserPoints(String docId) async {
    try {
      DocumentSnapshot docSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(docId).get();

      if (docSnapshot.exists) {
        var data = docSnapshot.data() as Map<String, dynamic>;
        var points = data['Points'];
        return points.toString();
      } else {
        return '0';
      }
    } catch (e) {
      print('Error: $e');
      return '0';
    }
  }

  // NEW: Add to Collections for admin tracking
  Future<void> _addToCollections(Map<String, dynamic> submissionData) async {
    try {
      String collectionId = randomAlphaNumeric(10);
      double weight = double.parse(submissionData["Weight"] ?? "0");

      await _firestore.collection("Collections").doc(collectionId).set({
        "userId": id,
        "userName": name ?? "Unknown User",
        "address": "User Submission", // You might want to get actual address
        "wasteType": submissionData["Type"],
        "quantity": weight,
        "collectionDate": FieldValue.serverTimestamp(),
        "status": "completed",
        "approvedBy": "user_submission", // Mark as user submission
        "requestId": collectionId,
        "createdAt": FieldValue.serverTimestamp(),
        "submissionType": "direct", // To distinguish from admin approvals
        "pointsEarned": submissionData["Points"],
      });

      print("Added to Collections: $weight kg of ${submissionData["Type"]}");
    } catch (e) {
      print("Error adding to collections: $e");
      throw e;
    }
  }

  Widget allApprovals() {
    return StreamBuilder(
      stream: pointsStream,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.green));
        }

        if (!snapshot.hasData || snapshot.data.docs.isEmpty) {
          return Center(
            child: Text(
              "No transactions yet",
              style: AppWidget.normaltextstyle(16.0),
            ),
          );
        }

        var sortedDocs = snapshot.data.docs.toList();
        sortedDocs.sort((a, b) {
          try {
            Timestamp? timestampA =
                a.exists && a.data().toString().contains('Timestamp')
                    ? a["Timestamp"]
                    : null;
            Timestamp? timestampB =
                b.exists && b.data().toString().contains('Timestamp')
                    ? b["Timestamp"]
                    : null;

            if (timestampA != null && timestampB != null) {
              return timestampB.compareTo(timestampA);
            } else if (timestampA != null) {
              return -1;
            } else if (timestampB != null) {
              return 1;
            } else {
              return 0;
            }
          } catch (e) {
            print('Error sorting documents: $e');
            return 0;
          }
        });

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot ds = sortedDocs[index];

            Map<String, dynamic> data =
                ds.exists ? ds.data() as Map<String, dynamic> : {};

            String type = data["Type"] ?? "Unknown";
            String points = data["Points"] ?? "0";
            String weight = data["Weight"] ?? "";
            String date = data["Date"] ?? "";
            String emailText = data["Email"] ?? "No email";

            return Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      date,
                      textAlign: TextAlign.center,
                      style: AppWidget.whitetextstyle(16.0),
                    ),
                  ),
                  SizedBox(width: 15.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type != " " ? "$type Submission" : "Redeem Points",
                          style: AppWidget.normaltextstyle(16.0),
                        ),
                        Text(
                          "$points points",
                          style: AppWidget.greentextstyle(18.0),
                        ),
                        if (weight.isNotEmpty)
                          Text(
                            "Weight: $weight kg",
                            style: AppWidget.normaltextstyle(14.0),
                          ),
                        if (emailText.isNotEmpty && emailText != "No email")
                          Text(
                            "Email: $emailText",
                            style: AppWidget.normaltextstyle(12.0),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reedem Points',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body:
          mypoints == null
              ? Center(child: CircularProgressIndicator(color: Colors.green))
              : Column(
                children: [
                  SizedBox(height: 20.0),
                  Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 30.0),

                        /// 🔥 NEW ADVANCED POINTS EARNED BOX
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 30.0),
                          child: Material(
                            elevation: 8.0,
                            shadowColor: Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(25),
                            child: Container(
                              padding: EdgeInsets.all(20),
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade100, Colors.white],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.2),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Coin with glow effect
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.yellow.withOpacity(0.6),
                                          blurRadius: 25,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      "images/coin.png",
                                      height: 70,
                                      width: 70,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 25.0),

                                  // Texts
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Points Earned",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        mypoints.toString(),
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          foreground:
                                              Paint()
                                                ..shader = LinearGradient(
                                                  colors: [
                                                    Colors.green,
                                                    Colors.teal,
                                                  ],
                                                ).createShader(
                                                  Rect.fromLTWH(0, 0, 200, 70),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 20.0),
                        GestureDetector(
                          onTap: () {
                            openGarbageSubmission();
                          },
                          child: Material(
                            elevation: 2.0,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 50,
                              width: MediaQuery.of(context).size.width / 1.5,
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  "Submit Garbage",
                                  style: AppWidget.whitetextstyle(20.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.0),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 10.0),
                          Text(
                            "Transaction History",
                            style: AppWidget.normaltextstyle(22.0),
                          ),
                          SizedBox(height: 10.0),
                          Expanded(child: allApprovals()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Future openGarbageSubmission() => showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Submit Garbage", style: AppWidget.greentextstyle(20.0)),
              IconButton(
                icon: Icon(Icons.close, color: Colors.green.shade900),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Garbage Type", style: AppWidget.normaltextstyle(16.0)),
                DropdownButtonFormField<String>(
                  value: selectedGarbageType,
                  items:
                      garbageTypePoints.keys.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedGarbageType = newValue!;
                    });
                  },
                ),
                SizedBox(height: 16),
                Text("Weight (kg)", style: AppWidget.normaltextstyle(16.0)),
                TextFormField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Enter weight in kilograms",
                  ),
                ),
                SizedBox(height: 16),
                Text("Email Address", style: AppWidget.normaltextstyle(16.0)),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: "Enter email address"),
                ),
                SizedBox(height: 16),
                Text(
                  "Earn Points: ${calculatePoints()}",
                  style: AppWidget.greentextstyle(18.0),
                ),
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: () async {
                      if (weightController.text.isNotEmpty &&
                          emailController.text.isNotEmpty) {
                        DateTime now = DateTime.now();
                        String formattedDate = DateFormat('d\nMMM').format(now);
                        int pointsEarned = calculatePoints();

                        Map<String, dynamic> garbageSubmissionMap = {
                          "Type": selectedGarbageType,
                          "Weight": weightController.text,
                          "Points": pointsEarned.toString(),
                          "Status": "Approved",
                          "Date": formattedDate,
                          "UserId": id,
                          "Email": emailController.text,
                          "GB_Collector's_Name": name,
                          "Timestamp": FieldValue.serverTimestamp(),
                        };

                        String submissionId = randomAlphaNumeric(10);

                        try {
                          // 1. Add to user submissions (existing functionality)
                          await DatabaseMethods().addGarbageSubmission(
                            garbageSubmissionMap,
                            id!,
                            submissionId,
                          );

                          // 2. NEW: Add to Collections for admin tracking
                          await _addToCollections(garbageSubmissionMap);

                          // 3. Update user points
                          int currentPoints = int.parse(mypoints!);
                          int newPoints = currentPoints + pointsEarned;
                          await DatabaseMethods().updateUserPoints(
                            id!,
                            newPoints.toString(),
                          );

                          setState(() {
                            mypoints = newPoints.toString();
                          });

                          weightController.clear();
                          emailController.clear();
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Earned $pointsEarned points! Added to total collection.",
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );

                          ontheload();
                        } catch (e) {
                          print("Error submitting garbage: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error submitting: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Please fill in all fields"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text(
                      "Submit Garbage",
                      style: AppWidget.whitetextstyle(18.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );

  int calculatePoints() {
    if (weightController.text.isEmpty) return 0;

    double weight = double.parse(weightController.text);
    int basePoints = garbageTypePoints[selectedGarbageType] ?? 0;

    return (basePoints * weight).round();
  }
}
