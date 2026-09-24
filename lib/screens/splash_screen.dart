import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';
import '../services/auth_service.dart';
import '../widgets/checker_strip.dart';
import '../utils/responsive.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    final user = await AuthService().currentUser();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => user == null ? const AuthScreen() : HomeScreen(username: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = Responsive.badge(MediaQuery.sizeOf(context).width,
        min: 110, max: 160, ratio: 0.36);
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      body: Container(
        decoration: QandTheme.headerGradient(radius: 0),
        padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _logo(logoSize),
                  const SizedBox(height: 16),
                  const Text('قندون',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontFamily: QandTheme.titleFont)),
                  const Text('فروشگاه کیک و شیرینی قند',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CheckerStrip(height: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo(double size) {
    return ClipOval(
      child: Image.asset('assets/logo/splash.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: Colors.white,
              child: const Center(
                  child: Text('قند',
                      style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD62828)))))),
    );
  }
}
