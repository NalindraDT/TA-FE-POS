import 'package:flutter/material.dart';
import 'screens/splash_screen.dart'; // <--- Wajib Import Splash Screen-nya

void main() {
  runApp(const AplikasiSaya());
}

class AplikasiSaya extends StatelessWidget {
  const AplikasiSaya({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Kasir D\'Latar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE65100)),
        useMaterial3: true,
      ),
      // --- UBAH BAGIAN INI ---
      home: const SplashScreen(),
    );
  }
}