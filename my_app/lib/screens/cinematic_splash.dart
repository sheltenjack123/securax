import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'dart:async';

class CinematicSplashScreen extends StatefulWidget {
  const CinematicSplashScreen({super.key});

  @override
  State<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends State<CinematicSplashScreen> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  
  // --- Animation Variables ---
  late Animation<double> _lockFade;
  late Animation<double> _lockScale;
  late Animation<double> _lidClose; // Controls the eye blink (0 = Open, 1 = Closed)
  late Animation<double> _bgFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _textBlur;

  @override
  void initState() {
    super.initState();

    // 1. Total Duration: 6 Seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000), 
    );

    // 2. Lock Fades In (0% - 15%)
    _lockFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    // 3. Lock Scale (Starts zoomed at 2.5x, goes to 1.0x after blink)
    _lockScale = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        // Waits until 40% (after blink finishes) to start zooming out
        curve: const Interval(0.40, 0.65, curve: Curves.easeInOutCubic), 
      ),
    );

    // 4. Eye Blink (Closes and Opens between 25% - 40%)
    // The Sequence makes it go 0 -> 1 (Closed) -> 0 (Open)
    _lidClose = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1), // Close
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1), // Open
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.40, curve: Curves.easeInOut),
      ),
    );

    // 5. Background Fades In (After lock zooms out: 65% - 85%)
    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.85, curve: Curves.easeIn),
      ),
    );

    // 6. Text Slides In (From Left: 70% - 90%)
    _textSlide = Tween<Offset>(
      begin: const Offset(-0.8, 0.0), // Starts from left
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.90, curve: Curves.easeOutExpo),
      ),
    );

    // 7. Text Blur (High Blur -> Clear: 70% - 90%)
    _textBlur = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.90, curve: Curves.easeOut),
      ),
    );

    // Start the Movie!
    _controller.forward();

    // Navigate to app home after 6.5 seconds (no in-app lock by default).
    Timer(const Duration(milliseconds: 6500), () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black, // Cinematic Black Background
      body: Stack(
        children: [
          
          // --- LAYER 1: Background Matrix (Appears Last) ---
          Positioned.fill(
            child: FadeTransition(
              opacity: _bgFade,
              child: Center(
                child: Image.asset(
                  'assets/icon/background_matrix.png',
                  width: screenWidth * 0.9,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // --- LAYER 2: Main Content (Lock + Text) ---
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Shrink to fit content
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                // A. THE LOCK (Appears -> Blinks -> Zooms Out)
                ScaleTransition(
                  scale: _lockScale,
                  child: FadeTransition(
                    opacity: _lockFade,
                    child: SizedBox(
                      width: 150, 
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. The Lock Image
                          Image.asset('assets/icon/lock_only.png'),

                          // 2. THE REALISTIC EYE BLINK OVERLAY
                          // This positions the blink exactly over the eye center.
                          Positioned(
                            // ⚠️ ADJUST THESE VALUES TO FIT YOUR IMAGE'S EYE SIZE EXACTLY
                            width: 50,  // Width of the eye ball in your PNG
                            height: 30, // Height of the eye ball in your PNG
                            // top: 60, // Uncomment and adjust if eye isn't vertically centered
                            
                            child: ClipOval( // <--- Cuts the eyelids into a perfect eye shape
                              child: Stack(
                                children: [
                                  // Top Eyelid (Moves Down)
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: AnimatedBuilder(
                                      animation: _lidClose,
                                      builder: (context, child) {
                                        return Container(
                                          width: double.infinity,
                                          // Expands from 0% to 60% height to close
                                          height: 30 * 0.60 * _lidClose.value, 
                                          color: Colors.black,
                                        );
                                      },
                                    ),
                                  ),
                                  
                                  // Bottom Eyelid (Moves Up)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedBuilder(
                                      animation: _lidClose,
                                      builder: (context, child) {
                                        return Container(
                                          width: double.infinity,
                                          // Expands from 0% to 60% height to close
                                          height: 30 * 0.60 * _lidClose.value,
                                          color: Colors.black,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30), // Space between Lock and Text

                // B. THE TEXT (Slides in with Motion Blur)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // Hide text completely until sequence starts (0.65)
                    if (_controller.value < 0.65) return const SizedBox(height: 40);

                    return SlideTransition(
                      position: _textSlide,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: _textBlur.value, // Horizontal Motion Blur
                          sigmaY: 0.0,
                        ),
                        child: Image.asset(
                          'assets/icon/text_logo.png',
                          width: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
