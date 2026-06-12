import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/screens/admin/add_user_screen.dart';
import 'package:tugasakhirpos/screens/login_screen.dart';
import 'package:tugasakhirpos/screens/user_profile_screen.dart';
import 'package:tugasakhirpos/config/api_config.dart';
import 'package:tugasakhirpos/screens/admin/admin_log_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _loggedInUserId;
  String _loggedInName = 'Admin';
  String _loggedInInitial = 'A';
  String? _loggedInFoto;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? nama = prefs.getString('nama_lengkap');
      _loggedInUserId = prefs.getString('id_user');

      if (nama != null && nama.isNotEmpty) {
        _loggedInName = nama;
        _loggedInInitial = nama[0].toUpperCase();
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['status'] == 200) {
          final List<dynamic> data = responseData['data'];
          final currentUser = data.firstWhere(
                (user) => user['id_user'].toString() == _loggedInUserId,
            orElse: () => null,
          );

          setState(() {
            _users = data;
            if (currentUser != null) {
              _loggedInFoto = currentUser['foto_profile'];
            }
            _isLoading = false;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'] ?? 'Gagal memuat data')),
            );
            setState(() => _isLoading = false);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengambil data: ${response.statusCode}')),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan jaringan: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logoutProses() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        content: const Text('Apakah Anda yakin ingin keluar dari sistem?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Menampilkan loading indikator karena sekarang kita harus nunggu respon API
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // 1. Tembak API Logout agar Backend mencatat Log Aktivitas (Tutup Shift)
      if (token != null) {
        // CATATAN: Pastikan endpoint '/logout' di bawah ini sesuai dengan Route di CI4 Master.
        // Jika route-nya misal '/auth/logout' atau metode GET, silakan sesuaikan.
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/user/logout'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      // 2. Hapus Token di Memori Lokal (Flutter)
      await prefs.clear();

      if (mounted) {
        // 3. Tutup Loading dan Arahkan ke Layar Login
        Navigator.pop(context); // Tutup CircularProgressIndicator
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<void> _resetPassword(String idUser, String namaUser) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Reset Password'),
        content: Text('Apakah Anda yakin ingin mereset password untuk $namaUser?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: TextStyle(color: Colors.amber.shade700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user/$idUser/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 200) {
        if (mounted) {
          String successMsg = responseData['messages']['success'] ?? 'Berhasil direset.';
          String infoMsg = responseData['messages']['info'] ?? '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successMsg\n$infoMsg'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mereset: ${responseData['message'] ?? 'Terjadi kesalahan'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- FUNGSI BARU UNTUK MENGUBAH STATUS AKTIF/NON-AKTIF ---
  Future<void> _toggleUserStatus(String idUser, String namaUser, bool currentStatus) async {
    // Tentukan nilai baru (Jika aktif jadi 0, jika non-aktif jadi 1)
    int newStatus = currentStatus ? 0 : 1;
    String actionText = currentStatus ? 'menonaktifkan' : 'mengaktifkan';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(currentStatus ? 'Non Aktifkan User' : 'Aktifkan User'),
        content: Text('Apakah Anda yakin ingin $actionText akun $namaUser?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              currentStatus ? 'Non Aktifkan' : 'Aktifkan',
              style: TextStyle(color: currentStatus ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true; // Munculkan loading indikator
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // CATATAN: Untuk update data RESTful CI4 biasanya pakai PUT.
      // Jika route Anda mengharuskan POST, ubah http.put menjadi http.post
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/user/$idUser'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'is_active': newStatus,
        }),
      );

      final responseData = jsonDecode(response.body);

      // Cek apakah HTTP status 200 (OK)
      if (response.statusCode == 200 && responseData['status'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status $namaUser berhasil diperbarui.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _fetchUsers(); // Refresh data untuk memperbarui badge di UI
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengubah status: ${responseData['message'] ?? 'Kesalahan server'}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, Color> _getRoleColors(String role) {
    String lowerRole = role.toLowerCase();
    if (lowerRole.contains('admin')) {
      return {'bg': Colors.indigo.shade50, 'text': Colors.indigo};
    } else if (lowerRole.contains('owner')) {
      return {'bg': Colors.orange.shade50, 'text': Colors.deepOrange};
    } else {
      return {'bg': Colors.grey.shade200, 'text': Colors.black87};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddUserScreen()),
          );
        },
        backgroundColor: const Color(0xFFE65100),
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),
      body: SafeArea(
      child: RefreshIndicator(
      color: const Color(0xFFE65100),
      backgroundColor: Colors.white,
      onRefresh: _fetchUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Wajib ada agar bisa ditarik
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_dlatar.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      radius: 20,
                      child: ClipOval(
                        child: (_loggedInFoto != null && _loggedInFoto!.isNotEmpty)
                            ? Image.network(
                          '${ApiConfig.baseUrl}/uploads/profile/$_loggedInFoto',
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _loggedInInitial,
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        )
                            : Text(
                          _loggedInInitial,
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    onSelected: (String value) {
                      if (value == 'profile') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserProfileScreen(),
                          ),
                        );
                      } else if (value == 'logout') {
                        _logoutProses();
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      _buildPopupMenuItem(
                        value: 'profile',
                        icon: Icons.person_outline,
                        iconColor: Colors.blue.shade600,
                        text: 'Lihat Profil',
                      ),
                      const PopupMenuDivider(),
                      _buildPopupMenuItem(
                        value: 'logout',
                        icon: Icons.logout,
                        iconColor: Colors.red.shade600,
                        text: 'Logout',
                        textColor: Colors.red.shade600,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Manajemen User Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kelola hak akses dan data pengguna',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.people_alt,
                      iconColor: Colors.indigo,
                      count: _isLoading ? '-' : _users.length.toString(),
                      label: 'Total User',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.vpn_key,
                      iconColor: Colors.black87,
                      count: '0',
                      label: 'Pin Reset Request',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar User',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminLogScreen()),
                      );
                    },
                    child: const Text(
                      'Log User',
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFFE65100)),
                ),
              )
                  : _users.isEmpty
                  ? const Center(
                child: Text('Tidak ada data user ditemukan.'),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final namaLengkap = user['nama_lengkap'] ?? 'Tanpa Nama';
                  final inisial = namaLengkap.isNotEmpty ? namaLengkap[0].toUpperCase() : '?';
                  final role = user['role'] ?? 'Unknown';

                  final int statusInt = user['is_active'] ?? 1;
                  final bool isActive = statusInt == 1;

                  final roleColors = _getRoleColors(role);

                  return _buildUserCard(
                    context: context,
                    idUser: user['id_user'].toString(),
                    username: user['username'] ?? '',
                    initial: inisial,
                    name: namaLengkap,
                    role: role,
                    isActive: isActive,
                    fotoProfile: user['foto_profile'],
                    avatarColor: Colors.orange.shade100,
                    textColor: Colors.deepOrange,
                    badgeBgColor: roleColors['bg']!,
                    badgeTextColor: roleColors['text']!,
                    isCurrentUser: user['id_user'].toString() == _loggedInUserId,
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
       ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 16),
          Text(
            count,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard({
    required BuildContext context,
    required String idUser,
    required String username,
    required String initial,
    required String name,
    required String role,
    required bool isActive,
    required Color avatarColor,
    required Color textColor,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required bool isCurrentUser,
    String? fotoProfile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // AVATAR DENGAN IMAGE NETWORK
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle
            ),
            child: ClipOval(
              child: (fotoProfile != null && fotoProfile.isNotEmpty)
                  ? Image.network(
                '${ApiConfig.baseUrl}/uploads/profile/$fotoProfile',
                fit: BoxFit.cover,
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(initial, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                ),
              )
                  : Center(
                child: Text(initial, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        role,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeTextColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'Aktif' : 'Non Aktif',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          isCurrentUser
              ? const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Text(
              '(Anda)',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          )
              : PopupMenuButton<String>(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            onSelected: (String value) {
              if (value == 'reset') {
                _resetPassword(idUser, name);
              } else if (value == 'toggle_status') {
                // --- PANGGIL FUNGSI TOGGLE DI SINI ---
                _toggleUserStatus(idUser, name, isActive);
              } else {
                debugPrint('Menu yang dipilih: $value');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              _buildPopupMenuItem(value: 'reset', icon: Icons.sync, iconColor: Colors.amber.shade600, text: 'Reset Password'),

              // --- MENU DINAMIS (Berdasarkan status Aktif/Non-Aktif saat ini) ---
              _buildPopupMenuItem(
                value: 'toggle_status',
                icon: isActive ? Icons.block : Icons.check_circle_outline,
                iconColor: isActive ? Colors.grey.shade500 : Colors.green.shade600,
                text: isActive ? 'Non Aktifkan' : 'Aktifkan',
                textColor: isActive ? null : Colors.green.shade700, // Beri warna hijau jika opsi "Aktifkan"
              ),

              _buildPopupMenuItem(value: 'delete', icon: Icons.delete_outline, iconColor: Colors.red.shade600, text: 'Hapus Permanen', textColor: Colors.red.shade600),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String text,
    Color? textColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: textColor ?? const Color(0xFF2C3E50), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}