import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'package:tugasakhirpos/screens/admin/dashboard_screen.dart';
import 'package:tugasakhirpos/screens/owner/owner_dashboard_screen.dart';
import 'package:tugasakhirpos/screens/kasir/kasir_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString('token');
    // BACA ROLE DARI BRANKAS LOKAL
    String? role = prefs.getString('role');

    if (mounted) {
      if (token != null && token.isNotEmpty) {
        if (role != null && role.toLowerCase() == 'owner') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OwnerDashboardScreen()),
          );
        }else if (role != null && role.toLowerCase() == 'kasir') {
          // Tambahkan baris ini!
          Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (context) => const KasirDashboardScreen()));
        }else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        // TIDAK ADA TOKEN -> User belum login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Image.asset(
          'assets/images/logo_dlatar.png',
          width: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}