import 'package:flutter/material.dart';
import 'package:tugasakhirpos/screens/dashboard_screen.dart';

void main() {
  runApp(const AplikasiSaya());
}

class AplikasiSaya extends StatelessWidget {
  const AplikasiSaya({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home:DashboardScreen()
    );
  }
}