// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/manage_products_page/widgets/product_list/product_model.dart';

class PaginatedProductList extends StatefulWidget {
  final String category;

  const PaginatedProductList({super.key, required this.category});

  @override
  State<PaginatedProductList> createState() => _PaginatedProductListState();
}

class _PaginatedProductListState extends State<PaginatedProductList> {
  final int _limit = 10;
  final List<ProductModel> _products = [];

  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _initNamespace();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      _fetchProducts();
    }
  }

  Future<void> _initNamespace() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('cachedCompanyId');

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No company found in session')),
      );
      return;
    }

    setState(() => _companyId = id);
    await clearCache(_companyId!, widget.category);

    await _loadCachedProducts(); // Load local cache first
    await _fetchProducts(); // Then refresh from Firestore
  }

  bool _fuzzyMatch(String text, String query) {
    if (query.isEmpty) return true;
    text = text.toLowerCase();
    query = query.toLowerCase();

    int i = 0, j = 0;
    while (i < text.length && j < query.length) {
      if (text[i] == query[j]) j++;
      i++;
    }
    return j == query.length;
  }

  List<ProductModel> get _filteredProducts {
    if (_searchTerm.isEmpty) return _products;

    return _products.where((p) {
      final name = p.displayName.toLowerCase();
      final q = _searchTerm.toLowerCase();
      return name.contains(q) || _fuzzyMatch(name, q);
    }).toList();
  }

  Future<void> _loadCachedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_products_${widget.category}_$_companyId';
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null && mounted) {
      final decoded = List<Map<String, dynamic>>.from(jsonDecode(cachedData));
      final cachedList = decoded.map((e) => ProductModel.fromMap(e)).toList();

      setState(() {
        _products
          ..clear()
          ..addAll(cachedList);
      });
    }
  }

  Future<void> _cacheProductsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_products_${widget.category}_$_companyId';
    final encoded = jsonEncode(_products.map((p) => p.toMap()).toList());
    await prefs.setString(cacheKey, encoded);
  }

  /// Force delete the cache (manual refresh)
  Future<void> clearCache(String companyId, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_products_${category}_$companyId';
    await prefs.remove(cacheKey);
  }

  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore || _companyId == null) return;

    setState(() => _isLoading = true);

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products')
        .where('category', isEqualTo: widget.category)
        .orderBy('displayName');
        // .limit(_limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      final snapshot = await query.get();

      if (snapshot.docs.length < _limit) _hasMore = false;
      if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;

      final newProducts = snapshot.docs.map((doc) {
        final data = doc.data();
        return ProductModel.fromMap({...data, 'id': doc.id});
      }).toList();

      // ✅ Prevent duplication
      for (final p in newProducts) {
        if (_products.every((existing) => existing.id != p.id)) {
          _products.add(p);
        }
      }

      await _cacheProductsLocally();
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteProduct(String docId) async {
    if (_companyId == null) return;

    await FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products')
        .doc(docId)
        .delete();

    _products.removeWhere((p) => p.id == docId);
    await _cacheProductsLocally();
    setState(() {});
  }

  void _onSearchChanged(String value) {
    setState(() => _searchTerm = value.trim());
  }

  @override
  void didUpdateWidget(covariant PaginatedProductList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
      _isLoading = false;
      _loadCachedProducts();
      _fetchProducts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleList = _filteredProducts;

    return Column(
      children: [
        // 🔍 Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search ${widget.category} products by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // 🔽 Product List
        Expanded(
          child: _products.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? Center(
                      child:
                          Text('No ${widget.category} products found.'),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: visibleList.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visibleList.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final product = visibleList[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Icon(
                              widget.category == 'Raw'
                                  ? Icons.settings_input_component
                                  : Icons.done_all,
                              color: Colors.lightBlue,
                            ),
                            title: Text(product.displayName),
                            subtitle: Text(
                              '₹ ${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            trailing: IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteProduct(product.id),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
