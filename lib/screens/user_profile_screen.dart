import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk PlatformException
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
// PACKAGE BARU UNTUK BIOMETRIK
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:tugasakhirpos/widgets/security_bottom_sheets.dart';
import 'package:tugasakhirpos/config/api_config.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _namaLengkapController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _noHpController = TextEditingController();

  String _originalNama = '';
  String _originalUsername = '';
  String _originalNoHp = '';

  bool _isLoading = true;
  bool _isSavingBiodata = false;
  bool _isEditingBiodata = false;
  bool _isUploadingPhoto = false;

  String _initial = 'A';
  String? _fotoProfileUrl;
  bool _hasPin = false;

  // --- STATE BIOMETRIK ---
  bool _hasBiometricRegistered = false;
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String _imageTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    _checkLocalBiometricStatus(); // Cek apakah di HP ini sudah ada token biometrik
  }

  @override
  void dispose() {
    _namaLengkapController.dispose();
    _usernameController.dispose();
    _noHpController.dispose();
    super.dispose();
  }

  // --- CEK STATUS BIOMETRIK LOKAL ---
  Future<void> _checkLocalBiometricStatus() async {
    String? localToken = await _secureStorage.read(key: 'biometric_token');
    setState(() {
      _hasBiometricRegistered = (localToken != null && localToken.isNotEmpty);
    });
  }

  // --- FUNGSI MENGHUBUNGKAN/MENDAFTARKAN BIOMETRIK ---
  Future<void> _registerBiometric() async {
    try {
      // 1. Cek Dukungan Perangkat
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        _showSnackBar('Perangkat Anda tidak mendukung fitur sidik jari/Face ID.', Colors.orange);
        return;
      }

      // 2. Minta User Melakukan Scan Sidik Jari untuk Konfirmasi
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan sidik jari Anda untuk mengaktifkan fitur Login Biometrik',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (!authenticated) {
        _showSnackBar('Registrasi dibatalkan.', Colors.red);
        return;
      }

      // 3. Jika Scan Berhasil, Buat Token Unik (UUID)
      const uuid = Uuid();
      String newBiometricToken = uuid.v4(); // Contoh: 110ec58a-a0f2-4ac4-8393-c866d813b8d1

      // 4. Tampilkan Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
      );

      // 5. Kirim Token ke API Backend (TUGAS MASTER UNTUK MEMBUAT API-NYA)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/register-biometric'), // Sesuaikan nama API Master
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'biometric_token': newBiometricToken,
        }),
      );

      if (mounted) Navigator.pop(context); // Tutup Loading

      // 6. Evaluasi Hasil dari API
      if (response.statusCode == 200) {
        // Jika sukses di DB, simpan token ke brankas HP
        await _secureStorage.write(key: 'biometric_token', value: newBiometricToken);
        setState(() => _hasBiometricRegistered = true);
        _showSnackBar('Biometrik berhasil didaftarkan!', Colors.green);
      } else {
        _showSnackBar('Gagal menyimpan ke server', Colors.red);
      }

    } on PlatformException catch (e) {
      debugPrint('Error Auth: $e');
      _showSnackBar('Terjadi kesalahan pada sensor sidik jari.', Colors.red);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pastikan loading tertutup jika ada error jaringan
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
    }
  }

  // --- FUNGSI MENGHAPUS BIOMETRIK ---
  Future<void> _removeBiometric() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Hapus Biometrik?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Anda tidak akan bisa lagi login menggunakan sidik jari/Face ID.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? jwtToken = prefs.getString('token');

      // 1. Tembak API Backend untuk mengosongkan (NULL) kolom biometric_token
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/register-biometric'), // Pakai API yang sama, tapi kirim kosong
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'biometric_token': null,
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        // 2. Hapus token dari brankas HP
        await _secureStorage.delete(key: 'biometric_token');
        setState(() => _hasBiometricRegistered = false);
        _showSnackBar('Login Biometrik berhasil dihapus.', Colors.green);
      } else {
        _showSnackBar('Gagal menghapus data di server.', Colors.red);
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
    }
  }

  // --- 1. FUNGSI FETCH DATA PROFIL ---
  Future<void> _fetchProfileData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 200) {
          final userData = responseData['data'];
          setState(() {
            _originalNama = userData['nama_lengkap'] ?? '';
            _originalUsername = userData['username'] ?? '';
            _originalNoHp = userData['no_hp'] ?? '';
            _hasPin = userData['has_pin'] ?? false;

            if (!isRefresh) {
              _namaLengkapController.text = _originalNama;
              _usernameController.text = _originalUsername;
              _noHpController.text = _originalNoHp;
            }

            _fotoProfileUrl = userData['foto_profile'];
            _initial = _originalNama.isNotEmpty ? _originalNama[0].toUpperCase() : 'A';
            _imageTimestamp = DateTime.now().millisecondsSinceEpoch.toString();

            _isLoading = false;
          });
        }
      } else {
        if (!isRefresh) _showSnackBar('Gagal memuat profil', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!isRefresh) _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // --- 2. FUNGSI UPDATE BIODATA ---
  Future<void> _updateBiodata() async {
    if (_namaLengkapController.text.isEmpty || _usernameController.text.isEmpty) {
      _showSnackBar('Nama Lengkap dan Username tidak boleh kosong!', Colors.orange);
      return;
    }

    setState(() => _isSavingBiodata = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/user/update-biodata'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nama_lengkap': _namaLengkapController.text,
          'username': _usernameController.text,
          'no_hp': _noHpController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && (responseData['status'] == 200 || responseData['status'] == 201)) {
        _showSnackBar(responseData['messages']?['success'] ?? 'Biodata berhasil diperbarui!', Colors.green);

        await prefs.setString('nama_lengkap', _namaLengkapController.text);
        await prefs.setString('username', _usernameController.text);

        setState(() {
          _originalNama = _namaLengkapController.text;
          _originalUsername = _usernameController.text;
          _originalNoHp = _noHpController.text;

          _initial = _originalNama.isNotEmpty ? _originalNama[0].toUpperCase() : 'A';
          _isEditingBiodata = false;
        });
      } else {
        _showErrorFromApi(responseData, 'Gagal menyimpan biodata');
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    } finally {
      setState(() => _isSavingBiodata = false);
    }
  }

  // --- 3. FUNGSI UPDATE & CROP FOTO PROFIL ---
  Future<void> _updatePhotoProfile() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Foto',
          toolbarColor: const Color(0xFFE65100),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Sesuaikan Foto',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) return;

    File imageFile = File(croppedFile.path);
    setState(() => _isUploadingPhoto = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/user/update-photo'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.files.add(await http.MultipartFile.fromPath('foto_profile', imageFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && (responseData['status'] == 200 || responseData['status'] == 201)) {
        _showSnackBar('Foto profil berhasil diperbarui!', Colors.green);
        await _fetchProfileData(isRefresh: true);
      } else {
        _showErrorFromApi(responseData, 'Gagal mengunggah foto');
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _showPasswordBottomSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UpdatePasswordBottomSheet(),
    );

    if (result == true) {
      _showSnackBar('Password berhasil diperbarui!', Colors.green);
      _fetchProfileData(isRefresh: true);
    }
  }

  Future<void> _showPinBottomSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpdatePinBottomSheet(hasPin: _hasPin),
    );

    if (result == true) {
      _showSnackBar('PIN Keamanan berhasil diperbarui!', Colors.green);
      _fetchProfileData(isRefresh: true);
    }
  }

  void _cancelEdit() {
    setState(() {
      _namaLengkapController.text = _originalNama;
      _usernameController.text = _originalUsername;
      _noHpController.text = _originalNoHp;
      _isEditingBiodata = false;
    });
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  void _showErrorFromApi(dynamic responseData, String defaultMsg) {
    String errorMsg = defaultMsg;
    if (responseData['messages'] != null && responseData['messages']['error'] != null) {
      errorMsg = responseData['messages']['error'];
    } else if (responseData['message'] != null) {
      errorMsg = responseData['message'];
    }
    _showSnackBar(errorMsg, Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE65100),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Navigator.canPop(context)
                        ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              const SizedBox(height: 60),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                    : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        _originalNama.isEmpty ? 'Tanpa Nama' : _originalNama,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50)),
                      ),
                      const SizedBox(height: 24),

                      // KOTAK PUTIH FORM BIODATA
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Informasi Biodata', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                                if (!_isEditingBiodata)
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Color(0xFFE65100), size: 28),
                                    onPressed: () => setState(() => _isEditingBiodata = true),
                                  )
                              ],
                            ),
                            const SizedBox(height: 16),

                            _buildLabel('Nama Lengkap'),
                            _isEditingBiodata
                                ? _buildTextField(_namaLengkapController, Icons.person_outline, 'Masukkan Nama Lengkap')
                                : _buildDisabledField(_originalNama),
                            const SizedBox(height: 16),

                            _buildLabel('Username'),
                            _isEditingBiodata
                                ? _buildTextField(_usernameController, Icons.alternate_email, 'Masukkan Username')
                                : _buildDisabledField(_originalUsername),
                            const SizedBox(height: 16),

                            _buildLabel('Nomer HP (WhatsApp)'),
                            _isEditingBiodata
                                ? _buildTextField(_noHpController, Icons.phone_android, 'Contoh: 08123456789', isPhone: true)
                                : _buildDisabledField(_originalNoHp.isEmpty ? '-' : _originalNoHp),
                            const SizedBox(height: 24),

                            if (_isEditingBiodata)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: const BorderSide(color: Colors.grey),
                                      ),
                                      onPressed: _isSavingBiodata ? null : _cancelEdit,
                                      child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        backgroundColor: const Color(0xFFE65100),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _isSavingBiodata ? null : _updateBiodata,
                                      child: _isSavingBiodata
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),

                            // --- BAGIAN KEAMANAN ---
                            const Divider(height: 48),
                            const Text('Keamanan Akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Icon(Icons.lock_outline, color: Colors.grey),
                                const SizedBox(width: 12),
                                const Text('Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                                const Spacer(),
                                TextButton(
                                  onPressed: _showPasswordBottomSheet,
                                  child: Text('Ganti Password', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.pin_outlined, color: Colors.grey),
                                const SizedBox(width: 12),
                                const Text('PIN Keamanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                                const SizedBox(width: 8),
                                Icon(_hasPin ? Icons.check_circle : Icons.cancel, color: _hasPin ? Colors.green : Colors.red, size: 16),
                                const Spacer(),
                                TextButton(
                                  onPressed: _showPinBottomSheet,
                                  child: Text(_hasPin ? 'Ubah PIN' : 'Tambah PIN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                ),
                              ],
                            ),

                            // --- PENAMBAHAN BIOMETRIK ---
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.fingerprint_rounded, color: Colors.grey),
                                const SizedBox(width: 12),
                                const Text('Login Sidik Jari', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                                const SizedBox(width: 8),
                                Icon(_hasBiometricRegistered ? Icons.check_circle : Icons.cancel, color: _hasBiometricRegistered ? Colors.green : Colors.red, size: 16),
                                const Spacer(),
                                TextButton(
                                  onPressed: _hasBiometricRegistered ? _removeBiometric : _registerBiometric,
                                  child: Text(
                                      _hasBiometricRegistered ? 'Hapus' : 'Aktifkan',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: _hasBiometricRegistered ? Colors.red.shade700 : Colors.blue.shade700)
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.shade100,
                      border: Border.all(color: const Color(0xFFF9F9F9), width: 5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: ClipOval(
                      child: _isUploadingPhoto
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                          : (_fotoProfileUrl != null && _fotoProfileUrl!.isNotEmpty)
                          ? Image.network(
                        '${ApiConfig.baseUrl}/uploads/profile/$_fotoProfileUrl?v=$_imageTimestamp',
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(),
                      )
                          : _buildInitialAvatar(),
                    ),
                  ),
                  if (!_isUploadingPhoto)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _updatePhotoProfile,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar() {
    return Center(child: Text(_initial, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange.shade800)));
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon, String hint, {bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE65100))),
      ),
    );
  }

  Widget _buildDisabledField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.black26, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}