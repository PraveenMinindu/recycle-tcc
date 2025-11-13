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
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

    // Responsive scaling factors
    final bool isSmallScreen = screenHeight < 600;
    final bool isLargeScreen = screenHeight > 800;

    // Responsive dimensions
    final double topImageHeight = _getResponsiveValue(
      screenHeight,
      300.0,
      200.0,
    );
    final double logoSize = _getResponsiveValue(screenHeight, 120.0, 80.0);
    final double headlineFontSize = _getResponsiveFontSize(screenHeight, 25.0);
    final double greenTextFontSize = _getResponsiveFontSize(screenHeight, 32.0);
    final double normalTextFontSize = _getResponsiveFontSize(
      screenHeight,
      20.0,
    );
    final double getStartedFontSize = _getResponsiveFontSize(
      screenHeight,
      24.0,
    );
    final double buttonTextFontSize = _getResponsiveFontSize(
      screenHeight,
      25.0,
    );
    final double buttonHeight = _getResponsiveValue(screenHeight, 80.0, 60.0);
    final double googleIconSize = _getResponsiveValue(screenHeight, 50.0, 40.0);

    // Responsive spacing
    final double smallSpacing = _getResponsiveValue(screenHeight, 20.0, 15.0);
    final double mediumSpacing = _getResponsiveValue(screenHeight, 30.0, 20.0);
    final double largeSpacing = _getResponsiveValue(screenHeight, 80.0, 50.0);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            child: Column(
              children: [
                // Top image
                Container(
                  width: double.infinity,
                  height: topImageHeight,
                  child: Image.asset("images/login.png", fit: BoxFit.cover),
                ),

                SizedBox(height: smallSpacing),

                // Logo
                Image.asset(
                  "images/recycle1.png",
                  height: logoSize,
                  width: logoSize,
                  fit: BoxFit.cover,
                ),

                SizedBox(height: smallSpacing),

                // Headline texts
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getResponsiveValue(screenWidth, 20.0, 15.0),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Reduce. Reuse. Recycle.",
                        textAlign: TextAlign.center,
                        style: AppWidget.healinetextstyle(headlineFontSize),
                      ),
                      SizedBox(height: 5.0),
                      Text(
                        "Repeat!",
                        style: AppWidget.greentextstyle(greenTextFontSize),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: largeSpacing),

                // Description texts
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getResponsiveValue(screenWidth, 30.0, 20.0),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Proper waste disposal is not just a habit, it's a responsibility.",
                        textAlign: TextAlign.center,
                        style: AppWidget.normaltextstyle(normalTextFontSize),
                      ),
                      SizedBox(height: 10.0),
                      Text(
                        "Get Started!",
                        style: AppWidget.greentextstyle(getStartedFontSize),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: mediumSpacing),

                // Google Sign In Button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _getResponsiveValue(screenWidth, 20.0, 15.0),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      AuthMethods().signInWithGoogle(context);
                    },
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: buttonHeight,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: _getResponsiveValue(
                                screenWidth,
                                20.0,
                                15.0,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(
                                _getResponsiveValue(screenWidth, 8.0, 6.0),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: Image.asset(
                                "images/google.png",
                                height: googleIconSize,
                                width: googleIconSize,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(
                              width: _getResponsiveValue(
                                screenWidth,
                                20.0,
                                15.0,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                "Sign in with Google",
                                style: AppWidget.whitetextstyle(
                                  buttonTextFontSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom padding for better scroll
                SizedBox(height: _getResponsiveValue(screenHeight, 40.0, 20.0)),
              ],
            ),
          ),
        ),
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
    if (dimension < 400) {
      return smallValue;
    } else if (dimension > 800) {
      return normalValue * 1.1;
    }
    return normalValue;
  }
}
