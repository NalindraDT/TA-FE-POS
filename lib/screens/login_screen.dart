import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:tugasakhirpos/widgets/login_bottom_sheet.dart';
import 'package:tugasakhirpos/config/api_config.dart';
import 'package:tugasakhirpos/screens/owner/owner_dashboard_screen.dart';
import 'package:tugasakhirpos/screens/kasir/kasir_dashboard_screen.dart';
// import 'admin/dashboard_screen.dart'; // Hapus komentar ini jika admin sudah dibuat

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- Inisialisasi Plugin Biometrik & Storage ---
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isBiometricAvailable = false; // Flag untuk menampilkan tombol fingerprint

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  // --- 1. CEK KETERSEDIAAN TOKEN BIOMETRIK ---
  Future<void> _checkBiometricSupport() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      // Baca token dari brankas HP
      String? storedToken = await _secureStorage.read(key: 'biometric_token');

      setState(() {
        // Hanya bernilai true jika hardware mendukung DAN token biometrik sudah ada
        _isBiometricAvailable = canCheckBiometrics && isDeviceSupported && (storedToken != null && storedToken.isNotEmpty);
      });
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
    }
  }

  // --- 2. FUNGSI LOGIN VIA BIOMETRIK ---
  Future<void> _loginWithBiometric() async {
    try {
      // Panggil sensor HP
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan sidik jari Anda untuk masuk ke D\'Latar',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) return;

      // Ambil token dari memori HP
      String? localToken = await _secureStorage.read(key: 'biometric_token');
      if (localToken == null || localToken.isEmpty) {
        _showSnackBar('Data biometrik tidak valid. Silakan login manual.', Colors.orange);
        return;
      }

      // Tampilkan Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
      );

      // Tembak API Login Biometrik Backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/login-biometric'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'biometric_token': localToken,
        }),
      );

      if (mounted) Navigator.pop(context); // Tutup Loading

      // Evaluasi Balasan API
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        String jwtToken = responseData['token'];
        var user = responseData['user'];
        String role = user['role'] ?? '';
        String idUser = user['id_user']?.toString() ?? '';
        String namaLengkap = user['nama_lengkap'] ?? '';

        // Simpan sesi ke SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', jwtToken);
        await prefs.setString('id_user', idUser);
        await prefs.setString('role', role);
        await prefs.setString('nama_lengkap', namaLengkap);

        _showSnackBar('Login Berhasil! Selamat datang $namaLengkap.', Colors.green);

        if (!mounted) return;

        // Redirect sesuai Role
        if (role == 'Owner') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OwnerDashboardScreen()));
        } else if (role == 'Kasir') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const KasirDashboardScreen()));
        } else {
          _showSnackBar('Role tidak dikenali.', Colors.red);
        }
      } else {
        final responseData = jsonDecode(response.body);
        _showSnackBar(responseData['message'] ?? 'Login biometrik gagal.', Colors.red);
      }
    } on PlatformException catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error sensor: $e');
      _showSnackBar('Pemindai sidik jari dibatalkan/error.', Colors.red);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background Gradient yang menutupi seluruh layar
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE65100), // Oranye Tua di pojok kiri atas
              Color(0xFFFFB74D), // Oranye lebih muda dan lembut di kanan bawah
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. LOGO D'LATAR
                    Image.asset(
                      'assets/images/logo_dlatar.png',
                      width: 140,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),

                    // 2. JUDUL
                    const Text(
                      'Selamat Datang',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Silakan login untuk masuk ke sistem',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- BLOK BIOMETRIK (HANYA TAMPIL JIKA TERSEDIA) ---
                    if (_isBiometricAvailable) ...[
                      // 3. AREA FINGERPRINT DENGAN EFEK GLOW
                      GestureDetector(
                        onTap: _loginWithBiometric, // <--- Memanggil fungsi biometrik
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.shade50,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            size: 72,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. INSTRUKSI SIDIK JARI
                      Text(
                        'Scan sidik jari Anda',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 5. PEMISAH "ATAU"
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'ATAU',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 6. TOMBOL LOGIN MANUAL (SELALU TAMPIL)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          // Memunculkan modal dari bawah layar
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const LoginBottomSheet(),
                          );
                        },
                        child: const Text(
                          'Login dengan Username',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}