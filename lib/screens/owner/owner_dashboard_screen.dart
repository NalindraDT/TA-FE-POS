import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/screens/login_screen.dart';
import 'package:tugasakhirpos/screens/user_profile_screen.dart';
import 'package:tugasakhirpos/screens/owner/owner_product_screen.dart';
import 'package:tugasakhirpos/screens/owner/owner_laporan_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tugasakhirpos/config/api_config.dart';
import 'package:tugasakhirpos/screens/owner/owner_pengaturan_screen.dart';
import 'package:tugasakhirpos/screens/owner/owner_log_screen.dart'; // Sesuaikan jalurnya

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedIndex = 0;
  String _ownerName = 'Owner';

  final List<Widget> _pages = [
    const OwnerHomeScreen(),        // Index 0: Konten Dashboard Utama
    const OwnerProductScreen(),     // Index 1: Halaman Produk
    const OwnerLaporanScreen(),
    const OwnerPengaturanScreen(),
    const UserProfileScreen(),      // Index 4: Akun
  ];

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _ownerName = prefs.getString('nama_lengkap') ?? 'Owner';
    });
  }

  Future<void> _logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?', style: TextStyle(fontSize: 14)),
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
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/user/logout'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        debugPrint('STATUS LOGOUT: ${response.statusCode}');
        debugPrint('BODY LOGOUT: ${response.body}');
      }

      // 2. Hapus Token di Memori Lokal (Flutter)
      await prefs.clear();

      if (context.mounted) {
        // 3. Tutup Loading dan Arahkan ke Layar Login
        Navigator.pop(context); // Tutup CircularProgressIndicator
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      // Failsafe: Jika internet mati/server error, TETAP paksa hapus token lokal
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    }
  }

  // Fungsi untuk mendapatkan teks judul tab lainnya
  String _getHeaderTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard'; // <-- Ditambahkan untuk merespon tab index 0
      case 1:
        return 'Produk';
      case 2:
        return 'Laporan';
      case 3:
        return 'Pengaturan';
      case 4:
        return 'User Profile';
      default:
        return '';
    }
  }

  // ==========================================
  // WIDGET HEADER DINAMIS (DISEDERHANAKAN)
  // ==========================================
  Widget _buildDynamicHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _getHeaderTitle(),
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50)
            ),
          ),
        ),

        // Deretan Ikon Kanan
        Row(
          children: [
            // TOMBOL LOG AKTIVITAS (Muncul Khusus di Tab Pengaturan / Index 3)
            if (_selectedIndex == 3)
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Color(0xFFE65100)),
                tooltip: 'Log Aktivitas',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OwnerLogScreen()),
                  );
                },
              ),

            // TOMBOL LOGOUT (Sembunyi di User Profile / Index 4)
            if (_selectedIndex != 4)
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.grey),
                tooltip: 'Keluar Akun',
                onPressed: () => _logout(context),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // HEADER DINAMIS (DISEMBUNYIKAN DI INDEX 4)
            // ==========================================
            if (_selectedIndex != 4) // <--- INI KUNCI RAHASIANYA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: _buildDynamicHeader(),
              ),

            // ==========================================
            // KONTEN TENGAH (PAGES)
            // ==========================================
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),

      // BOTTOM BAR GLOBAL
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE65100),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Produk'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Pengaturan'), // Dulu Kasir
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Akun'),
        ],
      ),
    );
  }
}

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  bool _isLoading = true;

  // Variabel penampung data API
  num _pendapatanKotor = 0;
  num _totalTransaksi = 0;
  num _menuTerjual = 0;
  List<dynamic> _topMenu = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  String _formatRupiah(num value) {
    String result = value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return 'Rp. $result';
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dashboard'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 200) {
          setState(() {
            // Ambil data hari ini
            var hariIni = responseData['data']['hari_ini'] ?? {};
            _pendapatanKotor = hariIni['pendapatan_kotor'] ?? 0;
            _totalTransaksi = hariIni['total_transaksi'] ?? 0;
            _menuTerjual = hariIni['menu_terjual'] ?? 0;

            // Ambil data top menu
            _topMenu = responseData['data']['top_menu'] ?? [];
            _isLoading = false;
          });
        } else {
          _showSnackBar('Gagal memuat data dashboard', Colors.red);
          setState(() => _isLoading = false);
        }
      } else {
        _showSnackBar('Terjadi kesalahan server: ${response.statusCode}', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error Dashboard: $e');
      _showSnackBar('Gagal terhubung ke server', Colors.red);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
    }

    return RefreshIndicator(
      color: const Color(0xFFE65100),
      backgroundColor: Colors.white,
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- REVENUE CARD DINAMIS ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE65100).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pendapatan Kotor Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(_formatRupiah(_pendapatanKotor), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat(Icons.receipt_long_rounded, 'Transaksi', _totalTransaksi.toString()),
                      _buildMiniStat(Icons.restaurant_rounded, 'Menu Terjual', _menuTerjual.toString()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- TOP MENU SECTION (Teks 'Bulan Ini' Dihapus) ---
            const Text('Menu Paling Laris', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 16),

            if (_topMenu.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Belum ada data penjualan', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._topMenu.asMap().entries.map((entry) {
                int index = entry.key;
                var menu = entry.value;

                Color rankColor;
                if (index == 0) {
                  rankColor = const Color(0xFFFFD700);
                } else if (index == 1) {
                  rankColor = const Color(0xFFC0C0C0);
                } else if (index == 2) {
                  rankColor = const Color(0xFFCD7F32);
                } else {
                  rankColor = Colors.grey.shade400;
                }

                String rank = (index + 1).toString();
                String nama = menu['nama_produk'] ?? 'Tanpa Nama';
                String terjual = menu['total_terjual']?.toString() ?? '0';
                String gambar = menu['gambar_produk'] ?? '';

                return _buildTopMenuItem(rank, nama, '$terjual Terjual', gambar, rankColor);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // --- KARTU MENU (Ikon Panah '>' Dihapus) ---
  Widget _buildTopMenuItem(String rank, String name, String sold, String imgFileName, Color rankColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 70,
                  height: 70,
                  color: Colors.orange.shade50,
                  child: imgFileName.isNotEmpty
                      ? Image.network(
                    '${ApiConfig.baseUrl}/uploads/produk/$imgFileName',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, color: Color(0xFFE65100)),
                  )
                      : const Icon(Icons.fastfood, color: Color(0xFFE65100)),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)
                  ),
                  child: Text(
                      rank,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                const SizedBox(height: 4),
                Text(sold, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          // const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey), <-- SUDAH DIBUANG
        ],
      ),
    );
  }
}
