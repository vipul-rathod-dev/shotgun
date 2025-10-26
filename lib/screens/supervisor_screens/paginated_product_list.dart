import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PaginatedProductList extends StatefulWidget {
  final String category;

  const PaginatedProductList({super.key, required this.category});

  @override
  State<PaginatedProductList> createState() => _PaginatedProductListState();
}

class _PaginatedProductListState extends State<PaginatedProductList> {
  final int _limit = 10;
  final List<DocumentSnapshot> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
          !_isLoading &&
          _hasMore) {
        _fetchProducts();
      }
    });
  }

  Future<void> _fetchProducts() async {
  if (_isLoading || !_hasMore) return;

  setState(() => _isLoading = true);

  Query query = FirebaseFirestore.instance
      .collection('products')
      .where('category', isEqualTo: widget.category)
      .orderBy('name') // Search works on ordered fields
      .limit(_limit);

  if (_searchTerm.isNotEmpty) {
    query = query
        .startAt([_searchTerm])
        .endAt(['$_searchTerm\uf8ff']);
  }

  if (_lastDocument != null) {
    query = query.startAfterDocument(_lastDocument!);
  }

  final snapshot = await query.get();

  if (snapshot.docs.length < _limit) _hasMore = false;

  if (snapshot.docs.isNotEmpty) {
    _lastDocument = snapshot.docs.last;
    _products.addAll(snapshot.docs);
  }

  setState(() => _isLoading = false);
}

  Future<void> _deleteProduct(String docId) async {
    await FirebaseFirestore.instance.collection('products').doc(docId).delete();
    _products.removeWhere((doc) => doc.id == docId);
    setState(() {});
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchTerm = value.trim();
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    _fetchProducts();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔍 Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products by name',
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // 🔽 Product List
        Expanded(
          child: _products.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? Center(child: Text('No ${widget.category} products found.'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _products.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _products.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final doc = _products[index];
                        final data = doc.data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Icon(
                              widget.category == 'Raw'
                                  ? Icons.settings_input_component
                                  : Icons.done_all,
                              color: Colors.deepPurple,
                            ),
                            title: Text(data['name'] ?? 'Unnamed'),
                            subtitle: widget.category == 'Raw'
                                ? const Text('')
                                : Text('₹ ${data['price'] ?? "N/A"}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(doc.id),
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
