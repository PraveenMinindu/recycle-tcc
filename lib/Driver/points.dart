import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:recycleapp/services/database.dart';
import 'package:recycleapp/services/shared_pref.dart';
import 'package:recycleapp/services/widget_support.dart';
import 'package:recycleapp/services/collection_service.dart';

class Points extends StatefulWidget {
  const Points({super.key});

  @override
  State<Points> createState() => _PointsState();
}

class _PointsState extends State<Points> {
  String? id, mypoints, name;
  Stream? pointsStream;
  final CollectionService _collectionService = CollectionService();
  final DatabaseMethods _databaseMethods = DatabaseMethods();

  getthesharedpref() async {
    id = await SharedpreferenceHelper().getUserId();
    name = await SharedpreferenceHelper().getUserName();
    setState(() {});
  }

  ontheload() async {
    await getthesharedpref();
    await refreshPointsAndStream();
  }

  Future<void> refreshPointsAndStream() async {
    String updatedPoints = await _databaseMethods.getUserPoints(id!);
    pointsStream = _databaseMethods.getUserSubmissions(id!);

    setState(() {
      mypoints = updatedPoints;
    });
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

  Widget allApprovals() {
    return StreamBuilder(
      stream: pointsStream,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.green));
        }

        if (snapshot.hasError) {
          print("Stream error: ${snapshot.error}");
          return Center(
            child: Text(
              "Error loading transactions",
              style: AppWidget.normaltextstyle(16.0),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data.docs.isEmpty) {
          return Center(
            child: Text(
              "No transactions yet",
              style: AppWidget.normaltextstyle(16.0),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: snapshot.data.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot ds = snapshot.data.docs[index];
            Map<String, dynamic> data = ds.data() as Map<String, dynamic>;

            String type = data["garbageType"] ?? "Unknown";
            String points = data["pointsEarned"]?.toString() ?? "0";
            String weight = data["weight"]?.toString() ?? "";
            String date = data["submissionDate"] ?? "";
            String emailText = data["userEmail"] ?? "No email";
            String source = data["source"] ?? "points_page";

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
                    child: Column(
                      children: [
                        Text(
                          date,
                          textAlign: TextAlign.center,
                          style: AppWidget.whitetextstyle(14.0),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                source == "points_page"
                                    ? Colors.orange
                                    : Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            source == "points_page" ? "User" : "Driver",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 15.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$type Submission",
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
          'Redeem Points',
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
                        // Points Earned Box
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 30.0),
                          child: Material(
                            elevation: 8.0,
                            shadowColor: Colors.green,
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
        (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                    Text(
                      "Garbage Type",
                      style: AppWidget.normaltextstyle(16.0),
                    ),
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
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Email Address",
                      style: AppWidget.normaltextstyle(16.0),
                    ),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: "Enter email address",
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Summary",
                            style: AppWidget.greentextstyle(16.0),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Garbage Type:"),
                              Text(
                                selectedGarbageType,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Weight:"),
                              Text(
                                "${weightController.text.isEmpty ? '0' : weightController.text} kg",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Points Earned:"),
                              Text(
                                "${calculatePoints()} points",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          if (weightController.text.isNotEmpty &&
                              emailController.text.isNotEmpty) {
                            double weight = double.parse(weightController.text);
                            int pointsEarned = calculatePoints();

                            try {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Colors.green,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          "Submitting garbage...",
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Adding ${weight}kg to today's total collection",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );

                              // Use DatabaseMethods to submit - includes total collection tracking
                              await _databaseMethods.submitUserGarbage(
                                userId: id!,
                                userName: name!,
                                garbageType: selectedGarbageType,
                                weight: weight,
                                email: emailController.text,
                                pointsEarned: pointsEarned,
                              );

                              // Update user points
                              await _databaseMethods.addUserPoints(
                                id!,
                                pointsEarned,
                              );

                              Navigator.pop(context);
                              weightController.clear();
                              emailController.clear();
                              Navigator.pop(context);

                              await refreshPointsAndStream();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Success! Earned $pointsEarned points!",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "${weight}kg of $selectedGarbageType added to today's collection",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            } catch (e) {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                              print("Error submitting garbage: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: ${e.toString()}"),
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
            );
          },
        ),
  );

  int calculatePoints() {
    if (weightController.text.isEmpty) return 0;

    try {
      double weight = double.parse(weightController.text);
      int basePoints = garbageTypePoints[selectedGarbageType] ?? 0;
      return (basePoints * weight).round();
    } catch (e) {
      return 0;
    }
  }
}
