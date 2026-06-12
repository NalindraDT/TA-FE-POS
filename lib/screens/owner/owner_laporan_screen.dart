import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';

class OwnerLaporanScreen extends StatefulWidget {
  const OwnerLaporanScreen({super.key});

  @override
  State<OwnerLaporanScreen> createState() => _OwnerLaporanScreenState();
}

class _OwnerLaporanScreenState extends State<OwnerLaporanScreen> {
  bool _isLoading = true;
  String _selectedPeriode = 'bulan';
  String _selectedKasirId = ''; // Kosong artinya 'Semua Kasir'

  // Ubah tipe list agar bisa menampung nilai komisi (double/int)
  List<Map<String, dynamic>> _kasirList = [
    {'id': '', 'nama': 'Semua Kasir', 'komisi': 0.0}
  ];

  Map<String, dynamic> _ringkasanKeuangan = {
    'pemasukan_owner': 0,
    'total_omset': 0,
    'bagi_hasil_kasir': 0,
  };
  List<dynamic> _statistikProduk = [];

  @override
  void initState() {
    super.initState();
    _fetchKasirList();
    _fetchLaporan();
  }

  String _formatRupiah(num value) {
    String result = value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return 'Rp. $result';
  }

  // ==========================================
  // 1. FETCH LIST KASIR (MENGGUNAKAN API BARU)
  // ==========================================
  Future<void> _fetchKasirList() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // Menggunakan endpoint khusus list-kasir
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/list-kasir'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<dynamic> users = responseData['data'] ?? [];

        List<Map<String, dynamic>> parsedKasir = [{'id': '', 'nama': 'Semua Kasir', 'komisi': 0.0}];

        for (var u in users) {
          parsedKasir.add({
            'id': u['id_user'].toString(),
            'nama': u['nama_lengkap'] ?? 'Kasir',
            // Pastikan mengambil nilai komisi dari API, default 0 jika kosong
            'komisi': double.tryParse(u['komisi']?.toString() ?? '0') ?? 0.0,
          });
        }

        setState(() {
          _kasirList = parsedKasir;
        });
      }
    } catch (e) {
      debugPrint('Error memuat daftar kasir: $e');
    }
  }

  // ==========================================
  // 2. FETCH LAPORAN & HITUNG PEMBAGIAN HASIL
  // ==========================================
  Future<void> _fetchLaporan() async {
    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      String url = '${ApiConfig.baseUrl}/laporan?periode=$_selectedPeriode';
      if (_selectedKasirId.isNotEmpty) {
        url += '&id_kasir=$_selectedKasirId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 200) {

          Map<String, dynamic> ringkasan = responseData['data']['ringkasan_keuangan'] ?? {};

          // --- LOGIKA PEMBAGIAN HASIL OTOMATIS FLUTTER ---
          // Jika Owner memilih 1 Kasir spesifik, kita hitung ulang komisinya
          if (_selectedKasirId.isNotEmpty) {
            double totalOmset = double.tryParse(ringkasan['total_omset'].toString()) ?? 0;

            // Cari persentase komisi kasir yang sedang dipilih
            var selectedKasirData = _kasirList.firstWhere((k) => k['id'] == _selectedKasirId, orElse: () => {'komisi': 0.0});
            double persentaseKomisi = selectedKasirData['komisi'] as double;

            // Kalkulasi Matematika
            double bagiHasil = (totalOmset * persentaseKomisi) / 100;
            double pemasukanOwner = totalOmset - bagiHasil;

            // Timpa data dari backend dengan hasil kalkulasi asli
            ringkasan['bagi_hasil_kasir'] = bagiHasil;
            ringkasan['pemasukan_owner'] = pemasukanOwner;
          }

          setState(() {
            _ringkasanKeuangan = ringkasan;
            _statistikProduk = responseData['data']['statistik_produk'] ?? [];
            _isLoading = false;
          });
        } else {
          _showSnackBar('Gagal memuat data laporan', Colors.red);
          setState(() => _isLoading = false);
        }
      } else {
        _showSnackBar('Terjadi kesalahan server: ${response.statusCode}', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error Laporan: $e');
      _showSnackBar('Gagal terhubung ke server', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _changePeriode(String periode) {
    if (_selectedPeriode == periode) return;
    setState(() {
      _selectedPeriode = periode;
    });
    _fetchLaporan();
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fungsi pembantu untuk format label dropdown agar menampilkan info komisi
    String _getKasirLabel(Map<String, dynamic> kasir) {
      if (kasir['id'] == '') return kasir['nama'];
      return '${kasir['nama']} (Komisi ${kasir['komisi']}%)';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: const Color(0xFFF9F9F9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                  builder: (context, constraints) {
                    return PopupMenuButton<String>(
                      initialValue: _selectedKasirId,
                      offset: const Offset(0, 50),
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        maxWidth: constraints.maxWidth,
                      ),
                      onSelected: (String newValue) {
                        setState(() {
                          _selectedKasirId = newValue;
                        });
                        _fetchLaporan();
                      },
                      itemBuilder: (BuildContext context) {
                        return _kasirList.map((kasir) {
                          return PopupMenuItem<String>(
                            value: kasir['id'] as String,
                            child: Text(
                              _getKasirLabel(kasir), // Menampilkan persentase komisi di dropdown
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getKasirLabel(_kasirList.firstWhere((k) => k['id'] == _selectedKasirId, orElse: () => {'nama': 'Semua Kasir', 'id': '', 'komisi': 0.0})),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  }
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  _buildFilterChip('Hari Ini', 'hari'),
                  const SizedBox(width: 12),
                  _buildFilterChip('Minggu Ini', 'minggu'),
                  const SizedBox(width: 12),
                  _buildFilterChip('Bulan Ini', 'bulan'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
              : RefreshIndicator(
            color: const Color(0xFFE65100),
            backgroundColor: Colors.white,
            onRefresh: _fetchLaporan,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ringkasan Keuangan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pemasukan Owner', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _formatRupiah(_ringkasanKeuangan['pemasukan_owner'] ?? 0),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF32CD32)),
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Omset', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatRupiah(_ringkasanKeuangan['total_omset'] ?? 0),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.black12),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Bagi Hasil Kasir', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '- ${_formatRupiah(_ringkasanKeuangan['bagi_hasil_kasir'] ?? 0)}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ==========================================
                  // STATISTIK PRODUK TERJUAL
                  // ==========================================
                  const Text('Detail Produk Terjual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 16),

                  if (_statistikProduk.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Belum ada penjualan di filter ini.', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _statistikProduk.length,
                      itemBuilder: (context, index) {
                        var produk = _statistikProduk[index];

                        String nama = produk['nama_produk'] ?? '-';
                        String gambar = produk['gambar_produk'] ?? '';
                        int terjual = int.tryParse(produk['total_terjual'].toString()) ?? 0;
                        double pendapatan = double.tryParse(produk['total_pendapatan'].toString()) ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: gambar.isNotEmpty
                                      ? Image.network(
                                    '${ApiConfig.baseUrl}/uploads/produk/$gambar',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood_rounded, color: Color(0xFFE65100)),
                                  )
                                      : const Icon(Icons.fastfood_rounded, color: Color(0xFFE65100)),
                                ),
                              ),
                              const SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50))),
                                    const SizedBox(height: 4),
                                    Text('$terjual Porsi Terjual', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              Text(
                                _formatRupiah(pendapatan),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF32CD32)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _selectedPeriode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changePeriode(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE65100) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? const Color(0xFFE65100) : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}