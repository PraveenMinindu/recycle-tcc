import 'package:flutter/material.dart';
import 'package:recycleapp/pages/login.dart';
import 'package:recycleapp/services/widget_support.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dark + Light Green Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B3D0B), // very dark green
                  Color(0xFF1F7A1F), // deep green
                  Color(0xFF4CAF50), // fresh light green
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),
                // Top illustration with gradient curved container
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF225522), // lighter dark green
                          Color(0xFF4CAF50), // mix with light green
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(80),
                        bottomRight: Radius.circular(80),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          offset: Offset(0, 5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Image.asset(
                        "images/onboard.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Headline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Text(
                    "Recycle Your Waste Products!",
                    textAlign: TextAlign.center,
                    style: AppWidget.healinetextstyle(28.0).copyWith(
                      color: Colors.green[50], // light greenish white
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    "Easily collect household waste and reduce environmental impact.",
                    textAlign: TextAlign.center,
                    style: AppWidget.normaltextstyle(
                      16.0,
                    ).copyWith(color: Colors.green[100]?.withOpacity(0.85)),
                  ),
                ),
                const SizedBox(height: 50),
                // Gradient Get Started button with a touch of light green
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LogIn()),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 70,
                    width: MediaQuery.of(context).size.width / 1.5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1F7A1F), // deep green
                          Color(0xFF4CAF50), // fresh light green
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          offset: Offset(0, 5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "Get Started",
                        style: AppWidget.whitetextstyle(24.0).copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[50],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
