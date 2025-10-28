import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/products_page/widgets/product_list/product_model.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch products from Firestore and refresh cache.
  Future<List<ProductModel>> fetchProducts({
    required String companyId,
    required String category,
    DocumentSnapshot? lastDoc,
    int limit = 10,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_products_${category}_$companyId';

    try {
      // 🧹 Clear old cache before writing new data
      await prefs.remove(cacheKey);

      Query<Map<String, dynamic>> query = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('products')
          .where('category', isEqualTo: category)
          .orderBy('displayName')
          .limit(limit);

      if (lastDoc != null) query = query.startAfterDocument(lastDoc);

      final snapshot = await query.get();

      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ProductModel.fromMap(data);
      }).toList();

      // Deduplicate
      final unique = {for (var p in results) p.id: p}.values.toList();

      // 💾 Write new cache (fresh)
      await prefs.setString(
        cacheKey,
        jsonEncode(unique.map((e) => e.toMap()).toList()),
      );

      return unique;
    } catch (e) {
      print('⚠️ Firestore fetch failed, loading cache instead: $e');
      return await loadCachedProducts(companyId, category);
    }
  }

  Future<void> deleteProduct(String companyId, String docId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('products')
        .doc(docId)
        .delete();
  }

  Future<List<ProductModel>> loadCachedProducts(
      String companyId, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_products_${category}_$companyId';

    final cached = prefs.getString(cacheKey);
    if (cached == null) return [];

    try {
      final decoded = List<Map<String, dynamic>>.from(jsonDecode(cached));
      return decoded.map(ProductModel.fromMap).toList();
    } catch (e) {
      print('⚠️ Cache decode failed, clearing corrupted cache: $e');
      await prefs.remove(cacheKey);
      return [];
    }
  }

  /// Force delete the cache (manual refresh)
  Future<void> clearCache(String companyId, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_products_${category}_$companyId';
    await prefs.remove(cacheKey);
  }
}
