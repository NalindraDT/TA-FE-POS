// Lokasi: lib/widgets/cart_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugasakhirpos/config/api_config.dart';

class CartBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final Function(List<Map<String, dynamic>>) onCartChanged;

  const CartBottomSheet({
    super.key,
    required this.cartItems,
    required this.onCartChanged,
  });

  @override
  State<CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends State<CartBottomSheet> {
  late List<Map<String, dynamic>> _localCart;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    // Gunakan data keranjang dari parent screen
    _localCart = widget.cartItems;
  }

  String _formatRupiah(num price) {
    String result = price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return 'Rp. $result';
  }

  double _getTotalPrice() {
    double total = 0;
    for (var item in _localCart) {
      total += (item['harga'] * item['kuantitas']);
    }
    return total;
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _localCart[index]['kuantitas'] += delta;
      if (_localCart[index]['kuantitas'] <= 0) {
        _localCart.removeAt(index);
      }
    });

    // Beritahu layar utama (parent) bahwa ada perubahan data keranjang
    widget.onCartChanged(_localCart);

    // Jika keranjang kosong, otomatis tutup modal
    if (_localCart.isEmpty) {
      Navigator.pop(context);
    }
  }

  // LOGIKA CHECKOUT (POST TRANSAKSI)
  Future<void> _processCheckout() async {
    setState(() => _isCheckingOut = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      List<Map<String, dynamic>> details = _localCart.map((item) {
        return {
          "id_produk": int.parse(item['id_produk'].toString()),
          "kuantitas_produk": item['kuantitas'],
          "harga_transaksi": item['harga'],
          "subtotal": item['harga'] * item['kuantitas']
        };
      }).toList();

      Map<String, dynamic> payload = {
        "total_harga": _getTotalPrice(),
        "metode_pembayaran": "Tunai",
        "details": details
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/transaksi'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      // CCTV: Intip apa yang dikembalikan CI4 setelah simpan data
      debugPrint('POST Transaksi Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        String idTransaksi = '';

        // Cara pintar mengekstrak ID Transaksi yang baru dibuat
        if (responseData.containsKey('id_transaksi')) {
          idTransaksi = responseData['id_transaksi'].toString();
        } else if (responseData.containsKey('data') && responseData['data'] is Map && responseData['data'].containsKey('id_transaksi')) {
          idTransaksi = responseData['data']['id_transaksi'].toString();
        }

        // Jika CI4 ternyata tidak mengirimkan ID transaksi sama sekali
        if (idTransaksi.isEmpty) {
          _showSnackBar('Pembayaran sukses, tapi Backend tidak mengirim ID Transaksi!', Colors.orange);
          // Kita tutup saja modalnya tanpa mencetak struk
          if (mounted) {
            setState(() => _isCheckingOut = false);
            Navigator.pop(context);
          }
          return;
        }

        // Jika ID ketemu, tutup modal keranjang dan lempar ID-nya ke Dashboard Kasir!
        if (mounted) Navigator.pop(context, idTransaksi);

      } else {
        _showSnackBar('Gagal memproses transaksi', Colors.red);
      }
    } catch (e) {
      debugPrint('Error Checkout: $e');
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Tinggi 75% layar
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 24),
          const Center(child: Text('Keranjang Pesanan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)))),
          const SizedBox(height: 24),

          TextField(
            decoration: InputDecoration(
              labelText: 'Atas nama:',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),

          Expanded(
            child: ListView.builder(
              itemCount: _localCart.length,
              itemBuilder: (context, index) {
                var item = _localCart[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.red, size: 18),
                              onPressed: () => _updateQuantity(index, -1),
                            ),
                            Text('${item['kuantitas']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.green, size: 18),
                              onPressed: () => _updateQuantity(index, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['nama_produk'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(_formatRupiah(item['harga']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(_formatRupiah(item['harga'] * item['kuantitas']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Tagihan', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text(_formatRupiah(_getTotalPrice()), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD84315), // Hijau
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isCheckingOut ? null : () => _processCheckout(),
              child: _isCheckingOut
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('BAYAR SEKARANG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}