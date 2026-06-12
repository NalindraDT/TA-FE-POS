// Lokasi: lib/widgets/security_bottom_sheets.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';

// ============================================================================
// WIDGET BOTTOM SHEET: GANTI PASSWORD
// ============================================================================
class UpdatePasswordBottomSheet extends StatefulWidget {
  const UpdatePasswordBottomSheet({super.key});

  @override
  State<UpdatePasswordBottomSheet> createState() => _UpdatePasswordBottomSheetState();
}

class _UpdatePasswordBottomSheetState extends State<UpdatePasswordBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();

  bool _isObscureOld = true;
  bool _isObscureNew = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/user/update-security'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'password_lama': _oldPassController.text,
          'password_baru': _newPassController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && (responseData['status'] == 200 || responseData['status'] == 201)) {
        if (mounted) Navigator.pop(context, true); // Sukses, kembalikan true
      } else {
        String errorTemp = 'Gagal mengganti password';
        if (responseData['messages'] != null && responseData['messages']['error'] != null) {
          errorTemp = responseData['messages']['error'];
        } else if (responseData['message'] != null) {
          errorTemp = responseData['message'];
        }
        if (mounted) setState(() => _errorMessage = errorTemp);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Text('Ganti Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 24),

            TextFormField(
              controller: _oldPassController,
              obscureText: _isObscureOld,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isObscureOld ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscureOld = !_isObscureOld),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
              ),
              validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _newPassController,
              obscureText: _isObscureNew,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(_isObscureNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscureNew = !_isObscureNew),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
              ),
              validator: (value) => value!.length < 6 ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 32),

            if (_errorMessage != null)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Password Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET BOTTOM SHEET: UBAH / TAMBAH PIN
// ============================================================================
class UpdatePinBottomSheet extends StatefulWidget {
  final bool hasPin;
  const UpdatePinBottomSheet({super.key, required this.hasPin});

  @override
  State<UpdatePinBottomSheet> createState() => _UpdatePinBottomSheetState();
}

class _UpdatePinBottomSheetState extends State<UpdatePinBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  // Tambahan Controller untuk Password Lama
  final _oldPassController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isObscureOld = true; // State visibility untuk password lama
  bool _isObscurePin = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/user/update-security'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        // Request Body Diperbarui Sesuai Permintaan Master
        body: jsonEncode({
          'password_lama': _oldPassController.text,
          'pin_baru': _pinController.text
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && (responseData['status'] == 200 || responseData['status'] == 201)) {
        if (mounted) Navigator.pop(context, true);
      } else {
        String errorTemp = 'Gagal menyimpan PIN';
        if (responseData['messages'] != null && responseData['messages']['error'] != null) {
          errorTemp = responseData['messages']['error'];
        } else if (responseData['message'] != null) {
          errorTemp = responseData['message'];
        }
        if (mounted) setState(() => _errorMessage = errorTemp);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _oldPassController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text(widget.hasPin ? 'Ubah PIN Keamanan' : 'Atur PIN Baru', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 24),

            // --- INPUT PASSWORD LAMA (BARU DITAMBAHKAN) ---
            TextFormField(
              controller: _oldPassController,
              obscureText: _isObscureOld,
              decoration: InputDecoration(
                labelText: 'Password Saat Ini',
                prefixIcon: const Icon(Icons.password_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_isObscureOld ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscureOld = !_isObscureOld),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
              ),
              validator: (value) => value!.isEmpty ? 'Password wajib diisi untuk verifikasi' : null,
            ),
            const SizedBox(height: 16),

            // --- INPUT PIN BARU ---
            TextFormField(
              controller: _pinController,
              obscureText: _isObscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Masukkan 6 Digit PIN',
                prefixIcon: const Icon(Icons.pin),
                suffixIcon: IconButton(
                  icon: Icon(_isObscurePin ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscurePin = !_isObscurePin),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
              ),
              validator: (value) => value!.length != 6 ? 'PIN wajib 6 angka' : null,
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}