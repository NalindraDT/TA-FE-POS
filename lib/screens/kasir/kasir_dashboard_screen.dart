import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';
import 'package:tugasakhirpos/screens/user_profile_screen.dart';
import 'package:tugasakhirpos/widgets/cart_bottom_sheet.dart';
import 'package:tugasakhirpos/screens/kasir/kasir_riwayat_screen.dart';
import 'package:tugasakhirpos/screens/login_screen.dart';
import 'package:tugasakhirpos/screens/kasir/kasir_log_screen.dart';

// ============================================================================
// WIDGET KERANGKA UTAMA KASIR (DASHBOARD)
// ============================================================================
class KasirDashboardScreen extends StatefulWidget {
  const KasirDashboardScreen({super.key});

  @override
  State<KasirDashboardScreen> createState() => _KasirDashboardScreenState();
}

class _KasirDashboardScreenState extends State<KasirDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const KasirMenuScreen(),
    const KasirRiwayatScreen(),
    const KasirLogScreen(),
    const UserProfileScreen(),
  ];

  // ==========================================
  // FUNGSI JUDUL HEADER DINAMIS KASIR
  // ==========================================
  String _getHeaderTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Riwayat Transaksi';
      case 2:
        return 'Log User';
      case 3:
        return 'User Profile';
      default:
        return 'Dashboard';
    }
  }

  // ==========================================
  // FUNGSI LOGOUT (Dipindah ke Dashboard Utama)
  // ==========================================
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token != null) {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/user/logout'),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        );
      }

      await prefs.clear();

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
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

  // ==========================================
  // WIDGET HEADER KASIR KONSISTEN
  // ==========================================
  Widget _buildDynamicHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _getHeaderTitle(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
        ),
        // Sembunyikan ikon logout jika sedang di User Profile (Index 3)
        if (_selectedIndex != 3)
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            tooltip: 'Keluar Akun',
            onPressed: () => _logout(context),
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
            // Header Dinamis muncul di atas semua halaman kecuali User Profile
            if (_selectedIndex != 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: _buildDynamicHeader(),
              ),

            // Konten Tengah
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE65100),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time_filled_rounded), label: 'Riwayat'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_rounded), label: 'Log User'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Akun'),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET KONTEN UTAMA KASIR (MENU GRID & KERANJANG) - BERSIH TANPA SEARCH BAR
// ============================================================================
class KasirMenuScreen extends StatefulWidget {
  const KasirMenuScreen({super.key});

  @override
  State<KasirMenuScreen> createState() => _KasirMenuScreenState();
}

class _KasirMenuScreenState extends State<KasirMenuScreen> {
  bool _isLoading = true;

  List<dynamic> _allProducts = [];
  List<dynamic> _displayedProducts = [];
  List<Map<String, String>> _categories = [];
  String _selectedCategoryId = '';

  // STATE KERANJANG PESANAN
  List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- FORMAT RUPIAH ---
  String _formatRupiah(num price) {
    String result = price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return 'Rp. $result';
  }

  IconData _getCategoryIcon(String categoryName) {
    String lower = categoryName.toLowerCase();
    if (lower.contains('makanan')) return Icons.restaurant;
    if (lower.contains('minuman')) return Icons.local_cafe;
    if (lower.contains('snack') || lower.contains('topping')) return Icons.icecream;
    return Icons.fastfood;
  }

  // --- FETCH PRODUK & KATEGORI ---
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
  // LOGIKA KERANJANG (CART)
  // ==========================================
  void _addToCart(dynamic product) {
    setState(() {
      int existingIndex = _cartItems.indexWhere((item) => item['id_produk'] == product['id_produk'].toString());

      if (existingIndex != -1) {
        _cartItems[existingIndex]['kuantitas'] += 1;
      } else {
        _cartItems.add({
          'id_produk': product['id_produk'].toString(),
          'nama_produk': product['nama_produk'].toString(),
          'harga': double.tryParse(product['harga'].toString()) ?? 0,
          'kuantitas': 1,
        });
      }
    });
  }

  double _getTotalPrice() {
    double total = 0;
    for (var item in _cartItems) {
      total += (item['harga'] * item['kuantitas']);
    }
    return total;
  }

  int _getTotalItems() {
    int total = 0;
    for (var item in _cartItems) {
      total += item['kuantitas'] as int;
    }
    return total;
  }

  // ==========================================
  // LOGIKA AMBIL & TAMPILKAN NOTA
  // ==========================================
  Future<void> _fetchAndShowReceipt(String idTransaksi) async {
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

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData.containsKey('transaksi')) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _showReceiptModal(responseData);
          });
        } else if (responseData['status']?.toString() == "200" && responseData['data'] != null) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _showReceiptModal(responseData['data']);
          });
        } else {
          _showSnackBar('Format data detail tidak sesuai', Colors.red);
        }
      } else {
        _showSnackBar('Gagal memuat detail nota', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
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

    return Stack(
      children: [
        Column(
          children: [
            // --- FILTER KATEGORI (Search bar & logo sudah dihapus) ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                      child: Text(cat['name']!, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                    ),
                  );
                },
              ),
            ),

            // --- LIST PRODUK GRID ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                  : ListView.builder(
                padding: EdgeInsets.only(left: 24, right: 24, top: 8, bottom: _cartItems.isNotEmpty ? 100 : 20),
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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180, childAspectRatio: 0.85, crossAxisSpacing: 16, mainAxisSpacing: 16,
                        ),
                        itemCount: productsInCategory.length,
                        itemBuilder: (context, gridIndex) {
                          var product = productsInCategory[gridIndex];
                          return _buildGridCard(product);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),

        // ==========================================
        // FLOATING BAR KERANJANG BAWAH
        // ==========================================
        if (_cartItems.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 24,
            right: 24,
            child: GestureDetector(
              onTap: _showCartBottomSheet,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFFE65100).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: Text('${_getTotalItems()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(_formatRupiah(_getTotalPrice()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Spacer(),
                    const Text('Lihat Pesanan >', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- WIDGET CARD PRODUK ---
  Widget _buildGridCard(dynamic product) {
    String imageUrl = product['gambar_produk'] ?? '';
    return GestureDetector(
      onTap: () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  color: Colors.grey.shade200,
                  child: (imageUrl.isNotEmpty)
                      ? Image.network(
                    '${ApiConfig.baseUrl}/uploads/produk/$imageUrl',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, color: Colors.grey, size: 40),
                  )
                      : const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(product['nama_produk'] ?? 'Tanpa Nama', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(_formatRupiah(double.tryParse(product['harga'].toString()) ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFD84315))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET BOTTOM SHEET: KERANJANG PESANAN
  // ==========================================
  void _showCartBottomSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CartBottomSheet(
        cartItems: _cartItems,
        onCartChanged: (updatedCart) {
          setState(() {
            _cartItems = updatedCart;
          });
        },
      ),
    );

    if (result != null) {
      setState(() {
        _cartItems.clear();
      });
      _fetchAndShowReceipt(result.toString());
    }
  }

  // ==========================================
  // WIDGET MODAL: DETAIL NOTA TRANSAKSI
  // ==========================================
  void _showReceiptModal(Map<String, dynamic> data) {
    var trx = data['transaksi'];
    List<dynamic> details = data['detail'] ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text('Detail Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)))),
                Center(child: Text('#${trx['kode_invoice']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE65100)))),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildReceiptRow('Waktu', trx['tanggal_transaksi'] ?? '-'),
                      const SizedBox(height: 8),
                      _buildReceiptRow('Atas Nama', 'Pelanggan'),
                      const SizedBox(height: 8),
                      _buildReceiptRow('Metode', trx['metode_pembayaran'] ?? 'Tunai'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

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
                              Text(_formatRupiah(double.tryParse(d['harga_transaksi'].toString()) ?? 0), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Text(_formatRupiah(double.tryParse(d['subtotal'].toString()) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL BAYAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_formatRupiah(double.tryParse(trx['total_harga'].toString()) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE65100))),
                  ],
                ),
                const SizedBox(height: 32),

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
                          backgroundColor: const Color(0xFFD84315),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          _showSnackBar('Menyiapkan printer Bluetooth...', Colors.blue);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.print_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('CETAK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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