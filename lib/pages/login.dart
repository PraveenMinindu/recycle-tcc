import 'package:flutter/material.dart';
import 'package:recycleapp/services/auth.dart';
import 'package:recycleapp/services/widget_support.dart';

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
          children: [
            Center(
              child: Image.asset(
                "images/login.png",
                height: 300,
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 20.0),
            Image.asset(
              "images/recycle1.png",
              height: 120,
              width: 120,
              fit: BoxFit.cover,
            ),
            SizedBox(height: 20.0),
            Text(
              "Reduce. Reuse. Recycle.",
              style: AppWidget.healinetextstyle(25.0),
            ),
            Text("Repeat!", style: AppWidget.greentextstyle(32.0)),
            SizedBox(height: 80.0),
            Text(
              "Proper waste disposal is not just a habit, it’s a responsibility.",
              textAlign: TextAlign.center,
              style: AppWidget.normaltextstyle(20.0),
            ),
            Text("Get Started!", style: AppWidget.greentextstyle(24.0)),
            SizedBox(height: 30.0),
            GestureDetector(
              onTap: () {
                AuthMethods().signInWithGoogle(context);
              },
              child: Container(
                margin: EdgeInsets.only(left: 20.0, right: 20.0),
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.only(left: 20.0),

                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: Image.asset(
                            "images/google.png",
                            height: 50,
                            width: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(width: 20.0),
                        Text(
                          "Sign in with Google",
                          style: AppWidget.whitetextstyle(25.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
