import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';

class KasirRiwayatScreen extends StatefulWidget {
  const KasirRiwayatScreen({super.key});

  @override
  State<KasirRiwayatScreen> createState() => _KasirRiwayatScreenState();
}

class _KasirRiwayatScreenState extends State<KasirRiwayatScreen> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  String _formatRupiah(String price) {
    double parsed = double.tryParse(price) ?? 0;
    String result = parsed.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return 'Rp. $result';
  }

  // --- AMBIL DATA SEMUA TRANSAKSI ---
  Future<void> _fetchRiwayat() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/transaksi'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        setState(() {
          // CEK FORMAT RESPON DARI API
          if (responseData is List) {
            // Jika formatnya langsung Array [...] seperti endpoint transaksi Master
            _transactions = responseData;
          } else if (responseData is Map && responseData.containsKey('data')) {
            // Jika dibungkus Object {"data": [...]}
            _transactions = responseData['data'] ?? [];
          } else {
            _transactions = [];
          }
          _isLoading = false;
        });
      } else {
        _showSnackBar('Gagal memuat riwayat: Status ${response.statusCode}', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('ERROR FETCH RIWAYAT: $e');
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // --- AMBIL DETAIL TRANSAKSI & TAMPILKAN NOTA ---
  Future<void> _fetchAndShowReceipt(String idTransaksi) async {
    // Tampilkan Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/transaksi/$idTransaksi'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      // CCTV Debug: Intip apa yang dikirim server CI4
      debugPrint('Detail Response [$idTransaksi]: ${response.body}');

      if (mounted) Navigator.pop(context); // Tutup loading dialog

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // KITA UBAH PENGECEKANNYA DI SINI
        // Cek apakah respon langsung berisi objek 'transaksi'
        if (responseData.containsKey('transaksi')) {

          Future.delayed(const Duration(milliseconds: 100), () {
            // Langsung lempar responseData (tidak perlu ['data'])
            if (mounted) _showReceiptModal(responseData);
          });

        }
        // Fallback jika suatu saat CI4 dibungkus {"status": 200, "data": {...}}
        else if (responseData['status']?.toString() == "200" && responseData['data'] != null) {

          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _showReceiptModal(responseData['data']);
          });

        } else {
          _showSnackBar('Format data detail tidak sesuai', Colors.red);
        }
      } else {
        _showSnackBar('Server Error: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pastikan loading tutup jika error jaringan
      debugPrint('Error Detail Transaksi: $e');
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // --- HEADER & FILTER TANGGAL ---


          // --- LIST RIWAYAT ---
          // --- LIST RIWAYAT ---
          Expanded(
            // Tambahkan RefreshIndicator di sini!
            child: RefreshIndicator(
              color: const Color(0xFFE65100),
              backgroundColor: Colors.white,
              onRefresh: _fetchRiwayat, // Panggil fungsi ambil data saat ditarik
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                  : _transactions.isEmpty
                  ? ListView( // Gunakan ListView agar layar kosong tetap bisa ditarik
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Center(child: Text('Belum ada transaksi.', style: TextStyle(color: Colors.grey.shade600))),
                ],
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(), // Wajib ada agar list bisa ditarik
                padding: const EdgeInsets.all(20),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  var trx = _transactions[index];
                  String status = trx['status_pembayaran'] ?? 'Sudah Bayar';
                  bool isPaid = status.toLowerCase().contains('sudah');

                  return GestureDetector(
                    onTap: () => _fetchAndShowReceipt(trx['id_transaksi'].toString()),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: isPaid ? Colors.green.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Icon(isPaid ? Icons.money : Icons.qr_code_scanner, color: isPaid ? Colors.green : Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trx['kode_invoice'] ?? '#INV-000', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50))),
                                const SizedBox(height: 4),
                                Text(trx['tanggal_transaksi'] ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_formatRupiah(trx['total_harga'].toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD84315))),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: isPaid ? Colors.green.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text(isPaid ? 'Sudah Bayar' : 'Belum Bayar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? Colors.green.shade800 : Colors.red.shade800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Bantuan untuk kotak filter
  Widget _buildFilterInput(IconData icon, String hint) {
    return SizedBox(
      height: 40,
      child: TextField(
        readOnly: hint.contains('Mulai') || hint.contains('Akhir'), // Kalau tanggal, bikin readonly (bisa ditambah fungsi showDatePicker nanti)
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 16),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET MODAL: DETAIL NOTA TRANSAKSI
  // ==========================================
  void _showReceiptModal(Map<String, dynamic>? data) {
    if (data == null || data['transaksi'] == null) {
      _showSnackBar('Data transaksi tidak valid', Colors.red);
      return;
    }

    var trx = data['transaksi'];
    List<dynamic> details = data['detail'] ?? [];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          // --- KUNCI PUTIH BERSIH MATERIAL 3 ---
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent, // Mematikan efek rona tema
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('Detail Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)))),
                  Center(child: Text('#${trx['kode_invoice'] ?? 'INV-??'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE65100)))),
                  const SizedBox(height: 24),

                  // Info Umum
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        _buildReceiptRow('Waktu', trx['tanggal_transaksi'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildReceiptRow('Atas Nama', trx['nama_pelanggan'] ?? 'Pelanggan'),
                        const SizedBox(height: 8),
                        _buildReceiptRow('Metode', trx['metode_pembayaran'] ?? 'Tunai'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // List Item Nota
                  ...details.map((d) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${d['kuantitas_produk']}X', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['nama_produk'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(_formatRupiah(d['harga_transaksi'].toString()), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text(_formatRupiah(d['subtotal'].toString()), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Total Bayar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL BAYAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(_formatRupiah(trx['total_harga'].toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE65100))),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- TOMBOL CETAK & TUTUP (BERDAMPINGAN) ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF2C3E50)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('TUTUP', style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFFD84315), // Oranye gelap
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            _showSnackBar('Menyiapkan printer Bluetooth...', Colors.blue);
                            // TODO: Tambahkan logika package ESC/POS di sini nanti
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('CETAK STRUK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2C3E50))),
      ],
    );
  }
}