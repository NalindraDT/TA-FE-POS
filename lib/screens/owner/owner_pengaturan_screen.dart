import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';

class OwnerPengaturanScreen extends StatefulWidget {
  const OwnerPengaturanScreen({super.key});

  @override
  State<OwnerPengaturanScreen> createState() => _OwnerPengaturanScreenState();
}

class _OwnerPengaturanScreenState extends State<OwnerPengaturanScreen> {
  // --- STATE KASIR ---
  bool _isLoadingKasir = true;
  List<dynamic> _kasirList = [];

  // --- STATE KATEGORI ---
  bool _isLoadingKategori = true;
  List<dynamic> _kategoriList = [];

  @override
  void initState() {
    super.initState();
    _fetchKasirList();
    _fetchKategoriList();
  }

  // ==========================================
  // FUNGSI GET DATA KASIR
  // ==========================================
  Future<void> _fetchKasirList() async {
    setState(() => _isLoadingKasir = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/list-kasir'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 200) {
          setState(() {
            _kasirList = responseData['data'] ?? [];
            _isLoadingKasir = false;
          });
        }
      } else {
        _showSnackBar('Gagal memuat data kasir', Colors.red);
        setState(() => _isLoadingKasir = false);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
      setState(() => _isLoadingKasir = false);
    }
  }

  // ==========================================
  // FUNGSI UPDATE KOMISI KASIR
  // ==========================================
  Future<void> _updateKomisi(String idKasir, String namaKasir, double komisiBaru) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/user/update-komisi/$idKasir'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'persentase_komisi': komisiBaru}),
      );

      if (mounted) Navigator.pop(context); // Tutup loading

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('Komisi $namaKasir berhasil diubah menjadi $komisiBaru%', Colors.green);
        _fetchKasirList();
      } else {
        _showSnackBar('Gagal mengubah komisi: ${responseData['message'] ?? 'Kesalahan'}', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    }
  }

  // ==========================================
  // FUNGSI GET KATEGORI
  // ==========================================
  Future<void> _fetchKategoriList() async {
    setState(() => _isLoadingKategori = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // Mengambil data kategori
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kategori'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          // Menangani jika API merespons langsung dengan Array atau dibungkus "data"
          _kategoriList = decoded is List ? decoded : (decoded['data'] ?? []);
          _isLoadingKategori = false;
        });
      } else {
        _showSnackBar('Gagal memuat kategori', Colors.red);
        setState(() => _isLoadingKategori = false);
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke server', Colors.red);
      setState(() => _isLoadingKategori = false);
    }
  }

  // ==========================================
  // FUNGSI SAVE (TAMBAH/EDIT) KATEGORI
  // ==========================================
  Future<void> _saveKategori(String? idKategori, String nama, String deskripsi) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // Jika ID ada, maka PUT (Edit), jika tidak POST (Tambah)
      final url = idKategori != null
          ? Uri.parse('${ApiConfig.baseUrl}/kategori/$idKategori')
          : Uri.parse('${ApiConfig.baseUrl}/kategori');

      final requestMethod = idKategori != null ? http.put : http.post;

      final response = await requestMethod(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nama_kategori': nama,
          'deskripsi': deskripsi,
        }),
      );

      if (mounted) Navigator.pop(context); // Tutup loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(idKategori != null ? 'Kategori berhasil diperbarui!' : 'Kategori berhasil ditambahkan!', Colors.green);
        _fetchKategoriList(); // Refresh data kategori
      } else {
        final responseData = jsonDecode(response.body);
        _showSnackBar('Gagal menyimpan: ${responseData['message'] ?? 'Kesalahan'}', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    }
  }

  // ==========================================
  // FUNGSI HAPUS KATEGORI
  // ==========================================
  Future<void> _deleteKategori(String idKategori) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/kategori/$idKategori'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (mounted) Navigator.pop(context); // Tutup loading

      if (response.statusCode == 200) {
        _showSnackBar('Kategori berhasil dihapus!', Colors.green);
        _fetchKategoriList();
      } else if (response.statusCode == 409) {
        // PENANGANAN KHUSUS ERROR 1451 (RESTRICT FOREIGN KEY)
        final responseData = jsonDecode(response.body);
        String errorMsg = 'Kategori ini masih digunakan oleh produk.';

        // Membaca pesan error dari format CI4 (biasanya di messages.error atau message)
        if (responseData['messages'] != null && responseData['messages']['error'] != null) {
          errorMsg = responseData['messages']['error'];
        } else if (responseData['message'] != null) {
          errorMsg = responseData['message'];
        }

        // Menampilkan SnackBar warna Oranye (Peringatan)
        _showSnackBar(errorMsg, Colors.orange.shade800);
      } else {
        _showSnackBar('Gagal menghapus kategori', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    }
  }

  // --- SNACKBAR GLOBAL ---
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  // ==========================================
  // DIALOG KASIR
  // ==========================================
  void _showEditKomisiDialog(Map<String, dynamic> kasir) {
    final TextEditingController komisiController = TextEditingController(
      text: kasir['persentase_komisi']?.toString() ?? '0',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Atur Komisi Kasir', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Atur persentase bagi hasil untuk kasir bernama ${kasir['nama_lengkap']}.', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: komisiController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Persentase Komisi (%)',
                hintText: 'Contoh: 12.50',
                suffixText: '%',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              double? newKomisi = double.tryParse(komisiController.text);
              if (newKomisi != null) {
                Navigator.pop(context);
                _updateKomisi(kasir['id_user'].toString(), kasir['nama_lengkap'] ?? 'Kasir', newKomisi);
              } else {
                _showSnackBar('Format angka tidak valid!', Colors.orange);
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOG FORM KATEGORI (TAMBAH / EDIT)
  // ==========================================
  void _showKategoriFormDialog({Map<String, dynamic>? kategori}) {
    final bool isEdit = kategori != null;
    final TextEditingController namaController = TextEditingController(text: isEdit ? kategori['nama_kategori'] : '');
    final TextEditingController deskripsiController = TextEditingController(text: isEdit ? kategori['deskripsi'] : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 18)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width, // Agar dialog sedikit lebih lebar mengikuti layar
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LABEL & INPUT NAMA KATEGORI ---
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text('Nama Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
              ),
              TextField(
                controller: namaController,
                decoration: InputDecoration(
                  hintText: 'Misal: Makanan Berat',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.category_rounded, color: Colors.grey.shade400, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
                ),
              ),
              const SizedBox(height: 16),

              // --- LABEL & INPUT DESKRIPSI ---
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text('Deskripsi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
              ),
              TextField(
                controller: deskripsiController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Penjelasan singkat kategori',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () {
              if (namaController.text.trim().isEmpty) {
                _showSnackBar('Nama kategori wajib diisi!', Colors.orange);
                return;
              }
              Navigator.pop(context);
              _saveKategori(isEdit ? kategori['id_kategori'].toString() : null, namaController.text.trim(), deskripsiController.text.trim());
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOG KONFIRMASI HAPUS KATEGORI
  // ==========================================
  void _showDeleteKategoriConfirm(String idKategori, String namaKategori) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Kategori', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 18)),
        content: Text('Apakah Anda yakin ingin menghapus kategori "$namaKategori"?\n\nPastikan tidak ada menu produk yang masih menggunakan kategori ini.', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteKategori(idKategori);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // --- TAB BAR UI ---
          Container(
            color: const Color(0xFFF9F9F9),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              indicatorColor: const Color(0xFFE65100),
              indicatorWeight: 3,
              labelColor: const Color(0xFFE65100),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Komisi Kasir'),
                Tab(text: 'Kategori Menu'),
              ],
            ),
          ),

          // --- ISI KONTEN TAB ---
          Expanded(
            child: TabBarView(
              children: [
                _buildTabKomisiKasir(),
                _buildTabKategori(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UI KONTEN: TAB KOMISI KASIR
  // ==========================================
  Widget _buildTabKomisiKasir() {
    if (_isLoadingKasir) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
    }

    if (_kasirList.isEmpty) {
      return const Center(child: Text('Belum ada akun Kasir yang terdaftar.', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      color: const Color(0xFFE65100),
      backgroundColor: Colors.white,
      onRefresh: _fetchKasirList,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _kasirList.length,
        itemBuilder: (context, index) {
          var kasir = _kasirList[index];
          String nama = kasir['nama_lengkap'] ?? 'Tanpa Nama';
          String komisi = kasir['persentase_komisi']?.toString() ?? '0';
          String inisial = nama.isNotEmpty ? nama[0].toUpperCase() : 'K';
          String fotoUrl = kasir['foto_profile'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                  child: ClipOval(
                    child: fotoUrl.isNotEmpty
                        ? Image.network(
                      '${ApiConfig.baseUrl}/uploads/profile/$fotoUrl',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(child: Text(inisial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE65100)))),
                    )
                        : Center(child: Text(inisial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE65100)))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('Bagi Hasil: $komisi%', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Color(0xFFE65100)),
                  onPressed: () => _showEditKomisiDialog(kasir),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // UI KONTEN: TAB KATEGORI (DESAIN KONSISTEN)
  // ==========================================
  Widget _buildTabKategori() {
    if (_isLoadingKategori) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
    }

    return Column(
      children: [
        // --- HEADER & TOMBOL TAMBAH ---
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daftar Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100), // Warna Oranye Tema
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showKategoriFormDialog(),
              ),
            ],
          ),
        ),

        // --- DAFTAR KARTU KATEGORI ---
        Expanded(
          child: _kategoriList.isEmpty
              ? const Center(child: Text('Belum ada data kategori.', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
            color: const Color(0xFFE65100),
            backgroundColor: Colors.white,
            onRefresh: _fetchKategoriList,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: _kategoriList.length,
              itemBuilder: (context, index) {
                var kategori = _kategoriList[index];
                String id = kategori['id_kategori']?.toString() ?? '';
                String nama = kategori['nama_kategori'] ?? '-';
                String deskripsi = kategori['deskripsi'] ?? 'Tidak ada deskripsi';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      // Ikon Tag Kategori
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.category_rounded, color: Color(0xFFE65100), size: 24),
                      ),
                      const SizedBox(width: 16),

                      // Info Kategori
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
                            const SizedBox(height: 4),
                            Text(deskripsi, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),

                      // Tombol Titik Tiga (Popup Menu) yang Jauh Lebih Rapi
                      PopupMenuButton<String>(
                        color: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showKategoriFormDialog(kategori: kategori);
                          } else if (value == 'delete') {
                            _showDeleteKategoriConfirm(id, nama);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                                const SizedBox(width: 12),
                                const Text('Edit Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                                const SizedBox(width: 12),
                                const Text('Hapus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}