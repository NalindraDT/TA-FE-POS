import 'package:flutter/material.dart';
import 'package:tugasakhirpos/screens/add_user_screen.dart';
import 'package:tugasakhirpos/screens/edit_user_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        backgroundColor: const Color(0xFFE65100), // Warna oranye D'Latar
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),

      // SafeArea agar tidak tertutup notch/status bar HP
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CUSTOM HEADER (Logo & Logout)
              Row(
                children: [
                  // Placeholder untuk Logo D'Latar (bisa diganti Image.asset nanti)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant_menu, color: Colors.deepOrange, size: 20),
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
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.logout, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 2. TITLE SECTION
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
                'Manajemen User Account',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // 3. SUMMARY CARDS ROW
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.people_alt,
                      iconColor: Colors.indigo,
                      count: '4',
                      label: 'Total User',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.vpn_key,
                      iconColor: Colors.black87,
                      count: '1',
                      label: 'Pin Reset Request',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 4. DAFTAR USER HEADER
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
                    onPressed: () {},
                    child: const Text(
                      'Log user',
                      style: TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. LIST OF USER CARDS
              // Menggunakan Column alih-alih ListView karena datanya sedikit dan ada di dalam SingleChildScrollView
              _buildUserCard(
                context: context,
                initial: 'N',
                name: 'Nalindra DT',
                role: 'Super Admin',
                avatarColor: Colors.orange.shade100,
                textColor: Colors.deepOrange,
                badgeBgColor: Colors.indigo.shade50,
                badgeTextColor: Colors.indigo,
              ),
              _buildUserCard(
                context: context,
                initial: 'N',
                name: 'Neni Diana',
                role: 'Owner',
                avatarColor: Colors.orange.shade100,
                textColor: Colors.deepOrange,
                badgeBgColor: Colors.indigo.shade50,
                badgeTextColor: Colors.indigo,
              ),
              _buildUserCard(
                context: context,
                initial: 'D',
                name: 'Dewi Hapsari',
                role: 'Owner',
                avatarColor: Colors.orange.shade100,
                textColor: Colors.deepOrange,
                badgeBgColor: Colors.indigo.shade50,
                badgeTextColor: Colors.indigo,
              ),
              _buildUserCard(
                context: context,
                initial: 'K',
                name: 'Kasir',
                role: 'Kasir',
                avatarColor: Colors.grey.shade300,
                textColor: Colors.black54,
                badgeBgColor: Colors.grey.shade300,
                badgeTextColor: Colors.black87,
              ),

              const SizedBox(height: 80), // Ruang ekstra di bawah agar tidak tertutup FAB
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET KUSTOM: Untuk Kotak Summary (Total User & Pin Reset)
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
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 16),
          Text(
            count,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET KUSTOM: Untuk Baris Daftar User
  Widget _buildUserCard({
    required BuildContext context,
    required String initial,
    required String name,
    required String role,
    required Color avatarColor,
    required Color textColor,
    required Color badgeBgColor,
    required Color badgeTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Lingkaran
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Nama & Badge Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // POPUP MENU (Pengganti IconButton sebelumnya)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Membuat ujung menu melengkung
            ),
            elevation: 4, // Bayangan menu
            onSelected: (String value) {
              if (value == 'edit') {
                // Navigasi ke halaman Edit dengan membawa data dummy
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditUserScreen(
                      initialUserData: {
                        'id': '101', // Data ini disimulasikan
                        'name': name, // Mengambil parameter 'name' dari fungsi pembuat kartu
                        'username': '${name.replaceAll(' ', '').toLowerCase()}21', // Dummy username
                        'role': role, // Mengambil parameter 'role' dari fungsi pembuat kartu
                      },
                    ),
                  ),
                );
              } else {
                debugPrint('Menu yang dipilih: $value');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              _buildPopupMenuItem(
                value: 'edit',
                icon: Icons.edit_outlined,
                iconColor: Colors.blue.shade600,
                text: 'Edit Data',
              ),
              _buildPopupMenuItem(
                value: 'reset',
                icon: Icons.sync, // Menggunakan ikon panah melingkar
                iconColor: Colors.amber.shade600,
                text: 'Reset Password',
              ),
              _buildPopupMenuItem(
                value: 'disable',
                icon: Icons.block,
                iconColor: Colors.grey.shade500,
                text: 'Non Aktifkan',
              ),
              _buildPopupMenuItem(
                value: 'delete',
                icon: Icons.delete_outline,
                iconColor: Colors.red.shade600,
                text: 'Hapus Permanen',
                textColor: Colors.red.shade600, // Teks khusus merah
              ),
              _buildPopupMenuItem(
                value: 'log',
                icon: Icons.access_time, // Menggunakan ikon jam
                iconColor: Colors.orange.shade400,
                text: 'Log User',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // WIDGET BANTUAN BARU: Untuk menyusun isi dari PopupMenu agar kodenya rapi
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
            style: TextStyle(
              color: textColor ?? const Color(0xFF2C3E50), // Default warna teks gelap
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}