import 'dart:async';
import 'package:flutter/material.dart';
import 'emis_webview_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), _navigateToWebView);
  }

  void _navigateToWebView() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EmisWebviewScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF101B58),
              Color(0xFF174A91),
              Color(0xFF168DAD),
              Color(0xFFEAF7FF),
            ],
            stops: [0, .38, .72, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -70,
              child: _glow(250, Colors.white.withOpacity(.08)),
            ),
            Positioned(
              bottom: -90,
              right: -55,
              child: _glow(280, const Color(0xFF55D6BE).withOpacity(.15)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10265C).withOpacity(.34),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.14),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded, color: Colors.white, size: 54),
                      SizedBox(height: 22),
                      Text(
                        'مساعد EMIS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .3,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 3)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'للمعلم',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFE0F7FF),
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 34,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
