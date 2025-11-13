import 'package:flutter/material.dart';
import 'package:recycleapp/Driver/login.dart';
import 'package:recycleapp/services/widget_support.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

    // Responsive scaling factors
    final bool isSmallScreen = screenHeight < 600;
    final bool isLargeScreen = screenHeight > 800;

    // Responsive dimensions
    final double topPadding = isSmallScreen ? 20.0 : screenHeight * 0.06;
    final int illustrationFlex = isSmallScreen ? 3 : 4; // Changed to int
    final double headlineFontSize = _getResponsiveFontSize(screenHeight, 28.0);
    final double descriptionFontSize = _getResponsiveFontSize(
      screenHeight,
      16.0,
    );
    final double buttonFontSize = _getResponsiveFontSize(screenHeight, 24.0);
    final double buttonHeight = isSmallScreen ? 60.0 : screenHeight * 0.08;
    final double buttonWidth = screenWidth * 0.65;
    final double borderRadius = _getResponsiveValue(screenHeight, 40.0, 30.0);
    final double bottomRadius = _getResponsiveValue(screenHeight, 80.0, 60.0);

    return Scaffold(
      body: Stack(
        children: [
          // Dark + Light Green Gradient background
          Container(
            width: double.infinity,
            height: double.infinity,
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
                SizedBox(height: topPadding),

                // Top illustration with gradient curved container
                Expanded(
                  flex: illustrationFlex, // Now this is int
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(
                      horizontal: _getResponsiveValue(screenWidth, 20.0, 10.0),
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF225522), // lighter dark green
                          Color(0xFF4CAF50), // mix with light green
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(bottomRadius),
                        bottomRight: Radius.circular(bottomRadius),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          offset: Offset(
                            0,
                            _getResponsiveValue(screenHeight, 5.0, 3.0),
                          ),
                          blurRadius: _getResponsiveValue(
                            screenHeight,
                            15.0,
                            10.0,
                          ),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        _getResponsiveValue(screenWidth, 20.0, 15.0),
                      ),
                      child: Image.asset(
                        "images/onboard.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: _getResponsiveValue(screenHeight, 30.0, 20.0)),

                // Headline
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getResponsiveValue(screenWidth, 30.0, 20.0),
                  ),
                  child: Text(
                    "Recycle Your Waste Products!",
                    textAlign: TextAlign.center,
                    style: AppWidget.healinetextstyle(
                      headlineFontSize,
                    ).copyWith(
                      color: Colors.green[50], // light greenish white
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SizedBox(height: _getResponsiveValue(screenHeight, 20.0, 15.0)),

                // Description
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getResponsiveValue(screenWidth, 40.0, 25.0),
                  ),
                  child: Text(
                    "Easily collect household waste and reduce environmental impact.",
                    textAlign: TextAlign.center,
                    style: AppWidget.normaltextstyle(
                      descriptionFontSize,
                    ).copyWith(color: Colors.green[100]?.withOpacity(0.85)),
                  ),
                ),

                SizedBox(height: _getResponsiveValue(screenHeight, 50.0, 30.0)),

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
                    height: buttonHeight,
                    width: buttonWidth,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1F7A1F), // deep green
                          Color(0xFF4CAF50), // fresh light green
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          offset: Offset(
                            0,
                            _getResponsiveValue(screenHeight, 5.0, 3.0),
                          ),
                          blurRadius: _getResponsiveValue(
                            screenHeight,
                            12.0,
                            8.0,
                          ),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "Get Started",
                        style: AppWidget.whitetextstyle(
                          buttonFontSize,
                        ).copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[50],
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: _getResponsiveValue(screenHeight, 40.0, 25.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to calculate responsive font sizes
  double _getResponsiveFontSize(double screenHeight, double baseSize) {
    if (screenHeight < 600) {
      return baseSize * 0.8; // Small screens
    } else if (screenHeight > 800) {
      return baseSize * 1.1; // Large screens
    }
    return baseSize; // Normal screens
  }

  // Helper method to calculate responsive values
  double _getResponsiveValue(
    double dimension,
    double normalValue,
    double smallValue,
  ) {
    return dimension < 400 ? smallValue : normalValue;
  }
}
