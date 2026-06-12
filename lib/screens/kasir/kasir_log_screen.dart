import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';

class KasirLogScreen extends StatefulWidget {
  const KasirLogScreen({super.key});

  @override
  State<KasirLogScreen> createState() => _KasirLogScreenState();
}

class _KasirLogScreenState extends State<KasirLogScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];

  // --- STATE PAGINASI ---
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  // --- MENGAMBIL DATA LOG AKTIVITAS KASIR ---
  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // Memanggil endpoint log dengan parameter halaman aktif
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/log-aktivitas?page=$_currentPage'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 200) {
          setState(() {
            _logs = responseData['data'] ?? [];
            _totalPages = responseData['pagination']['total_halaman'] ?? 1;
            _isLoading = false;
          });
        }
      } else {
        _showSnackBar('Gagal memuat data log', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA DERETAN KOTAK ANGKA PAGINASI (Max 5 Kotak) ---
  List<int> _generatePageNumbers() {
    List<int> pages = [];
    if (_totalPages <= 5) {
      for (int i = 1; i <= _totalPages; i++) {
        pages.add(i);
      }
    } else {
      if (_currentPage <= 3) {
        pages = [1, 2, 3, 4, 5];
      } else if (_currentPage >= _totalPages - 2) {
        pages = [_totalPages - 4, _totalPages - 3, _totalPages - 2, _totalPages - 1, _totalPages];
      } else {
        pages = [_currentPage - 2, _currentPage - 1, _currentPage, _currentPage + 1, _currentPage + 2];
      }
    }
    return pages;
  }

  // --- FORMAT TANGGAL AGAR SERASI DENGAN GAMBAR LOG ---
  String _formatDate(String datetimeStr) {
    try {
      DateTime dt = DateTime.parse(datetimeStr);
      String day = dt.day.toString().padLeft(2, '0');
      String month = dt.month.toString().padLeft(2, '0');
      String year = dt.year.toString();
      String hour = dt.hour.toString().padLeft(2, '0');
      String min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $day/$month/$year';
    } catch (e) {
      return datetimeStr;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- DAFTAR CONTAINER LOG AKTIVITAS ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
              : _logs.isEmpty
              ? const Center(child: Text('Belum ada riwayat aktivitas.', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
            color: const Color(0xFFE65100),
            backgroundColor: Colors.white,
            onRefresh: _fetchLogs,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                var log = _logs[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kiri: Label Tetap (Nama, Role, Aktivitas)
                      const SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nama:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 14)),
                            SizedBox(height: 6),
                            Text('Role:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 14)),
                            SizedBox(height: 6),
                            Text('Aktivitas:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 14)),
                          ],
                        ),
                      ),

                      // Kanan: Nilai Dinamis dari API
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(log['nama_lengkap'] ?? '-', style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50))),
                                ),
                                Text(_formatDate(log['created_at'] ?? ''), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(log['role'] ?? '-', style: const TextStyle(fontSize: 13, color: Color(0xFF673AB7))), // Warna Ungu Custom
                            const SizedBox(height: 6),
                            Text(log['keterangan'] ?? '-', style: const TextStyle(fontSize: 14, color: Colors.black87), softWrap: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // ==========================================
        // KONTROL PAGINASI KOTAK ANGKA ELEGAN
        // ==========================================
        if (!_isLoading && _totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tombol Mundur (Prev)
                GestureDetector(
                  onTap: _currentPage > 1
                      ? () {
                    setState(() => _currentPage--);
                    _fetchLogs();
                  }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _currentPage > 1 ? Colors.orange.shade50 : Colors.grey.shade100,
                    ),
                    child: Icon(Icons.chevron_left_rounded, color: _currentPage > 1 ? const Color(0xFFE65100) : Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),

                // Deretan Angka Dinamis
                ..._generatePageNumbers().map((pageNumber) {
                  bool isActive = pageNumber == _currentPage;
                  return GestureDetector(
                    onTap: () {
                      if (_currentPage != pageNumber) {
                        setState(() => _currentPage = pageNumber);
                        _fetchLogs();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFE65100) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isActive ? const Color(0xFFE65100) : Colors.grey.shade300),
                        boxShadow: isActive ? [BoxShadow(color: const Color(0xFFE65100).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
                      ),
                      child: Text(
                        pageNumber.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isActive ? Colors.white : const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(width: 12),

                // Tombol Maju (Next)
                GestureDetector(
                  onTap: _currentPage < _totalPages
                      ? () {
                    setState(() => _currentPage++);
                    _fetchLogs();
                  }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _currentPage < _totalPages ? Colors.orange.shade50 : Colors.grey.shade100,
                    ),
                    child: Icon(Icons.chevron_right_rounded, color: _currentPage < _totalPages ? const Color(0xFFE65100) : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}