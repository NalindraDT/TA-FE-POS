import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tugasakhirpos/config/api_config.dart';

class ForgotPasswordBottomSheet extends StatefulWidget {
  const ForgotPasswordBottomSheet({super.key});

  @override
  State<ForgotPasswordBottomSheet> createState() => _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState extends State<ForgotPasswordBottomSheet> {
  int _step = 1; // Step 1: Input HP, Step 2: Input OTP & Password Baru
  bool _isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  // ==========================================
  // FUNGSI 1: REQUEST OTP
  // ==========================================
  Future<void> _requestOtp() async {
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Nomor HP tidak boleh kosong!', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/request-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'no_hp': _phoneController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('OTP berhasil dikirim ke nomor Anda.', Colors.green);
        setState(() => _step = 2); // Pindah ke layar input OTP
      } else {
        final responseData = jsonDecode(response.body);
        _showSnackBar(responseData['message'] ?? 'Gagal mengirim OTP', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // FUNGSI 2: VERIFIKASI & RESET PASSWORD
  // ==========================================
  Future<void> _resetPassword() async {
    if (_otpController.text.trim().isEmpty || _newPasswordController.text.trim().isEmpty) {
      _showSnackBar('OTP dan Password Baru wajib diisi!', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/reset-password-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'no_hp': _phoneController.text.trim(),
          'otp': _otpController.text.trim(),
          'password_baru': _newPasswordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Password berhasil direset! Silakan login.', Colors.green);
        if (mounted) Navigator.pop(context); // Tutup modal setelah sukses
      } else {
        final responseData = jsonDecode(response.body);
        _showSnackBar(responseData['message'] ?? 'OTP Salah atau Kadaluarsa', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding dinamis agar modal tidak tertutup keyboard
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garis pemanis di atas modal
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _step == 1 ? 'Lupa Password?' : 'Reset Password',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 8),
          Text(
            _step == 1
                ? 'Masukkan nomor HP yang terdaftar untuk menerima kode OTP.'
                : 'Masukkan kode OTP yang dikirim ke ${_phoneController.text} beserta password baru Anda.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // ==========================================
          // UI STEP 1: INPUT NOMOR HP
          // ==========================================
          if (_step == 1) ...[
            const Text('Nomor HP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Contoh: 08123456789',
                prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFE65100))),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _requestOtp,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kirim Kode OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],

          // ==========================================
          // UI STEP 2: INPUT OTP & PASSWORD BARU
          // ==========================================
          if (_step == 2) ...[
            const Text('Kode OTP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 8),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Masukkan 6 digit OTP',
                prefixIcon: const Icon(Icons.message_rounded, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFE65100))),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Password Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Minimal 6 karakter',
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFE65100))),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            // Tombol kembali jika salah masukin nomor HP
            Center(
              child: TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Ubah Nomor HP', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}