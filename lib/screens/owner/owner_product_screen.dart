import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';
import 'package:tugasakhirpos/screens/owner/owner_add_product_screen.dart';
import 'package:tugasakhirpos/screens/owner/owner_edit_product_screen.dart';

class OwnerProductScreen extends StatefulWidget {
  const OwnerProductScreen({super.key});

  @override
  State<OwnerProductScreen> createState() => _OwnerProductScreenState();
}

class _OwnerProductScreenState extends State<OwnerProductScreen> {
  bool _isLoading = true;

  List<dynamic> _allProducts = [];
  List<dynamic> _displayedProducts = [];
  List<Map<String, String>> _categories = [];
  String _selectedCategoryId = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- FORMAT RUPIAH ---
  String _formatRupiah(num value) {
    String result = value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return 'Rp. $result';
  }

  IconData _getCategoryIcon(String categoryName) {
    String lower = categoryName.toLowerCase();
    if (lower.contains('makanan') || lower.contains('berat')) return Icons.restaurant;
    if (lower.contains('minuman')) return Icons.local_cafe;
    if (lower.contains('snack') || lower.contains('topping')) return Icons.icecream;
    return Icons.fastfood;
  }

  // ==========================================
  // FUNGSI GET DATA KATEGORI & PRODUK
  // ==========================================
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      var headers = {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'};

      final catResponse = await http.get(Uri.parse('${ApiConfig.baseUrl}/kategori'), headers: headers);
      final prodResponse = await http.get(Uri.parse('${ApiConfig.baseUrl}/produk'), headers: headers);

      if (catResponse.statusCode == 200 && prodResponse.statusCode == 200) {
        final catData = jsonDecode(catResponse.body);
        List<Map<String, String>> parsedCats = [{'id': '', 'name': 'Semua'}];
        List<dynamic> catList = catData is List ? catData : (catData['data'] ?? []);
        for (var c in catList) {
          parsedCats.add({'id': c['id_kategori'].toString(), 'name': c['nama_kategori'].toString()});
        }

        final prodData = jsonDecode(prodResponse.body);
        List<dynamic> productList = prodData['data'] ?? [];

        setState(() {
          _categories = parsedCats;
          _allProducts = productList;
          _displayedProducts = productList;
          _isLoading = false;
        });

        _filterProducts(_selectedCategoryId);
      } else {
        _showSnackBar('Gagal memuat data', Colors.red);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _filterProducts(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      if (categoryId.isEmpty) {
        _displayedProducts = _allProducts;
      } else {
        _displayedProducts = _allProducts.where((p) => p['id_kategori'].toString() == categoryId).toList();
      }
    });
  }

  // ==========================================
  // FUNGSI TOGGLE STATUS (MODE DETEKTIF / DEBUG PENUH)
  // ==========================================
  Future<void> _toggleProductStatus(Map<String, dynamic> produk, bool currentStatus) async {
    String idProduk = produk['id_produk'].toString();
    String namaProduk = produk['nama_produk'] ?? 'Tanpa Nama';
    int newStatus = currentStatus ? 0 : 1;
    String actionText = currentStatus ? 'menonaktifkan' : 'mengaktifkan';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(currentStatus ? 'Nonaktifkan Menu' : 'Aktifkan Menu', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 18)),
        content: Text('Apakah Anda yakin ingin $actionText menu "$namaProduk"?', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange.shade800 : Colors.green.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(currentStatus ? 'Nonaktifkan' : 'Aktifkan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      String? token = prefs.getString('token');
      String jsonPayload = jsonEncode({'is_active': newStatus});

      // === BLOK INSPEKSI SEBELUM KIRIM ===
      debugPrint('==================================================');
      debugPrint('🔍 [DEBUG START] TOGGLE STATUS PRODUK');
      debugPrint('📍 URL TUJUAN : ${ApiConfig.baseUrl}/produk/status/$idProduk');
      debugPrint('🔑 JWT TOKEN  : ${token != null ? "Ada (Mulai dengan: ${token.substring(0, min(15, token.length))}...)" : "KOSONG/NULL!"}');
      debugPrint('📦 JSON BODY  : $jsonPayload');
      debugPrint('==================================================');

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/produk/status/$idProduk'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonPayload,
      );

      // === BLOK INSPEKSI SETELAH TERIMA RESPON ===
      debugPrint('==================================================');
      debugPrint('📡 [DEBUG RESPONSE FROM SERVER]');
      debugPrint('🟢 STATUS CODE : ${response.statusCode}');
      debugPrint('📝 RAW BODY    : ${response.body}');
      debugPrint('==================================================');

      if (mounted) Navigator.pop(context); // Tutup Loading

      if (response.statusCode == 200) {
        _showSnackBar('Status "$namaProduk" berhasil diperbarui.', Colors.green);
        _fetchData();
      } else {
        final responseData = jsonDecode(response.body);
        String errorMsg = 'Gagal mengubah status.';

        if (responseData['messages'] != null && responseData['messages']['error'] != null) {
          errorMsg = responseData['messages']['error'].toString();
        } else if (responseData['message'] != null) {
          errorMsg = responseData['message'].toString();
        }

        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e, stacktrace) {
      if (mounted) Navigator.pop(context);
      debugPrint('==================================================');
      debugPrint('❌ [DEBUG CRITICAL ERROR]');
      debugPrint('Error  : $e');
      debugPrint('Trace  : $stacktrace');
      debugPrint('==================================================');
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    }
  }

  // Fungsi pembantu untuk memotong string token agar log rapi
  int min(int a, int b) => a < b ? a : b;

  // ==========================================
  // FUNGSI SOFT DELETE PRODUK
  // ==========================================
  Future<void> _deleteProduct(String idProduk, String namaProduk) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Produk', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontSize: 18)),
        content: Text('Anda yakin ingin menghapus produk "$namaProduk" secara permanen?', style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      String? token = prefs.getString('token');

      // Request DELETE akan memicu fitur soft deletes bawaan dari model CI4 Anda
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/produk/$idProduk'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        _showSnackBar('Produk berhasil dihapus!', Colors.green);
        _fetchData();
      } else {
        _showSnackBar('Gagal menghapus produk.', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Terjadi kesalahan jaringan.', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<dynamic>> groupedProducts = {};
    for (var p in _displayedProducts) {
      String cat = p['nama_kategori'] ?? 'Lainnya';
      if (!groupedProducts.containsKey(cat)) groupedProducts[cat] = [];
      groupedProducts[cat]!.add(p);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE65100),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OwnerAddProductScreen()),
          );
          if (result == true) _fetchData();
        },
      ),
      body: Column(
        children: [
          // --- FILTER KATEGORI (CHIPS) ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            height: 55,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategoryId == cat['id'];
                return GestureDetector(
                  onTap: () => _filterProducts(cat['id']!),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD84315) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? const Color(0xFFD84315) : Colors.grey.shade300, width: 1),
                    ),
                    child: Text(
                        cat['name']!,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13
                        )
                    ),
                  ),
                );
              },
            ),
          ),

          // --- LIST PRODUK BERDASARKAN KATEGORI ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : _displayedProducts.isEmpty
                ? const Center(child: Text('Belum ada produk di kategori ini.', style: TextStyle(color: Colors.grey)))
                : RefreshIndicator(
              color: const Color(0xFFE65100),
              backgroundColor: Colors.white,
              onRefresh: _fetchData,
              child: ListView.builder(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 80),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: groupedProducts.length,
                itemBuilder: (context, index) {
                  String categoryName = groupedProducts.keys.elementAt(index);
                  List<dynamic> productsInCategory = groupedProducts[categoryName]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: Row(
                          children: [
                            Icon(_getCategoryIcon(categoryName), color: Colors.black87, size: 24),
                            const SizedBox(width: 8),
                            Text(categoryName.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD84315))),
                            const SizedBox(width: 12),
                            Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1)),
                          ],
                        ),
                      ),

                      ...productsInCategory.map((produk) {
                        String id = produk['id_produk']?.toString() ?? '';
                        String nama = produk['nama_produk'] ?? 'Tanpa Nama';
                        String gambar = produk['gambar_produk'] ?? '';
                        double harga = double.tryParse(produk['harga']?.toString() ?? '0') ?? 0;
                        bool isActive = (produk['is_active']?.toString() ?? '1') == '1';

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
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: gambar.isNotEmpty
                                      ? Image.network(
                                    '${ApiConfig.baseUrl}/uploads/produk/$gambar',
                                    fit: BoxFit.cover,
                                    color: isActive ? null : Colors.white.withOpacity(0.5),
                                    colorBlendMode: isActive ? null : BlendMode.lighten,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, color: Colors.grey),
                                  )
                                      : const Icon(Icons.fastfood, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nama,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isActive ? const Color(0xFF2C3E50) : Colors.grey,
                                        decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                      ),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(_formatRupiah(harga), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isActive ? const Color(0xFFE65100) : Colors.grey)),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isActive ? 'Aktif' : 'Non-Aktif',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.green.shade700 : Colors.red.shade700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              PopupMenuButton<String>(
                                color: Colors.white,
                                surfaceTintColor: Colors.transparent,
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => OwnerEditProductScreen(product: produk))
                                    );
                                    if (result == true) _fetchData();
                                  } else if (value == 'toggle') {
                                    _toggleProductStatus(produk, isActive);
                                  } else if (value == 'delete') {
                                    _deleteProduct(id, nama);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                                        const SizedBox(width: 12),
                                        const Text('Edit Produk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: isActive ? Colors.orange : Colors.green, size: 18),
                                        const SizedBox(width: 12),
                                        Text(isActive ? 'Nonaktifkan' : 'Aktifkan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.orange.shade800 : Colors.green.shade800)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
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
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}