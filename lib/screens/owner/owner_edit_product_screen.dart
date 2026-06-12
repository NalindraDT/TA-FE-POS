import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tugasakhirpos/config/api_config.dart';

class OwnerEditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const OwnerEditProductScreen({super.key, required this.product});

  @override
  State<OwnerEditProductScreen> createState() => _OwnerEditProductScreenState();
}

class _OwnerEditProductScreenState extends State<OwnerEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _hargaController;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _isLoadingCats = true;

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Pre-fill data produk lama
    _namaController = TextEditingController(text: widget.product['nama_produk'] ?? '');
    _hargaController = TextEditingController(text: widget.product['harga']?.toString() ?? '');
    _selectedCategoryId = widget.product['id_kategori']?.toString();
    _fetchCategories();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/kategori'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final catData = jsonDecode(response.body);
        List<dynamic> catList = catData is List ? catData : (catData['data'] ?? []);

        List<Map<String, dynamic>> parsedCats = [];
        for (var c in catList) {
          parsedCats.add({
            'id': c['id_kategori'].toString(),
            'name': c['nama_kategori'].toString(),
          });
        }

        setState(() {
          _categories = parsedCats;
          _isLoadingCats = false;
        });
      } else {
        _showSnackBar('Gagal memuat kategori', Colors.red);
        setState(() => _isLoadingCats = false);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan', Colors.red);
      setState(() => _isLoadingCats = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showSnackBar('Silakan pilih kategori produk!', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String idProduk = widget.product['id_produk'].toString();

      // KUNCI PENTING: Gunakan POST, tapi sisipkan field _method: PUT
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/produk/$idProduk'));

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Spoofing method agar CI4 membaca ini sebagai PUT (Update)
      request.fields['_method'] = 'PUT';
      request.fields['id_kategori'] = _selectedCategoryId!;
      request.fields['nama_produk'] = _namaController.text;
      request.fields['harga'] = _hargaController.text;

      // Cuma kirim gambar kalau owner benar-benar memilih gambar baru
      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('gambar_produk', _selectedImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('Produk berhasil diperbarui!', Colors.green);
        if (mounted) Navigator.pop(context, true); // Kembali & kirim sinyal sukses
      } else {
        _showErrorFromApi(responseData, 'Gagal memperbarui produk');
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke server', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showErrorFromApi(dynamic responseData, String defaultMsg) {
    String errorMsg = defaultMsg;
    if (responseData['messages'] != null && responseData['messages']['error'] != null) {
      errorMsg = responseData['messages']['error'];
    } else if (responseData['message'] != null) {
      errorMsg = responseData['message'];
    }
    _showSnackBar(errorMsg, Colors.red);
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    String gambarLama = widget.product['gambar_produk'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFDFD),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2C3E50), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Produk', style: TextStyle(color: Color(0xFF2C3E50), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- KOTAK UPLOAD FOTO ---
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCECDD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE65100), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _selectedImage != null
                            ? Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity) // Gambar baru dipilih
                            : (gambarLama.isNotEmpty)
                            ? Image.network('${ApiConfig.baseUrl}/uploads/produk/$gambarLama', fit: BoxFit.cover, width: double.infinity, errorBuilder: (context, error, stackTrace) => _buildUploadPlaceholder()) // Gambar lama dari server
                            : _buildUploadPlaceholder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- NAMA PRODUK ---
                _buildLabel('Nama Produk'),
                TextFormField(
                  controller: _namaController,
                  decoration: _buildInputDecoration(Icons.restaurant, 'Masukkan nama produk'),
                  validator: (val) => val == null || val.isEmpty ? 'Nama produk wajib diisi' : null,
                ),
                const SizedBox(height: 20),

                // --- HARGA JUAL ---
                _buildLabel('Harga Jual (Rp)'),
                TextFormField(
                  controller: _hargaController,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration(Icons.money, '0'),
                  validator: (val) => val == null || val.isEmpty ? 'Harga wajib diisi' : null,
                ),
                const SizedBox(height: 20),

                // --- KATEGORI DROPDOWN ---
                _buildLabel('Kategori'),
                _isLoadingCats
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                    : DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  hint: const Text('Pilih Kategori'),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  decoration: _buildInputDecoration(Icons.list_alt_rounded, ''),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['id'],
                      child: Text(cat['name']),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCategoryId = value),
                  validator: (val) => val == null ? 'Pilih kategori terlebih dahulu' : null,
                ),
                const SizedBox(height: 48),

                // --- TOMBOL SIMPAN ---
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD84315),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _saveProduct,
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.upload_rounded, color: Color(0xFFE65100), size: 60),
        const SizedBox(height: 8),
        Text('Ganti foto produk', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
    );
  }

  InputDecoration _buildInputDecoration(IconData icon, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE65100))),
    );
  }
}