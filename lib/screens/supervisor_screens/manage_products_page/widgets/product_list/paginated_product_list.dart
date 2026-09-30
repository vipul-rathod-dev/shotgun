// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/supervisor_screens/manage_products_page/widgets/product_list/product_model.dart';

class PaginatedProductList extends StatefulWidget {
  final String category;

  const PaginatedProductList({
    super.key,
    required this.category,
  });

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

  // ---------------------------------------------------------------------------
  // PAGINATION
  // ---------------------------------------------------------------------------

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 150 &&
        !_isLoading &&
        _hasMore) {
      _fetchProducts();
    }
  }

  String _getType(ProductModel product) {
    return product.type.isEmpty ? '-' : product.type;
  }

  IconData _getProductIcon() {
    switch (widget.category) {
      case 'Raw':
        return Icons.settings_input_component_outlined;

      case 'Finished':
        return Icons.shopping_bag_outlined;

      case 'Other':
        return Icons.category_outlined;

      default:
        return Icons.inventory_2_outlined;
    }
  }

  Future<void> _initNamespace() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('cachedCompanyId');

    if (id == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No company found in session'),
        ),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      _companyId = id;
    });

    // Load cached data first.
    await _loadCachedProducts();

    // Then fetch the latest Firestore data.
    await _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore || _companyId == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products')
        .where(
          'category',
          isEqualTo: widget.category,
        )
        .orderBy('displayName')
        .limit(_limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        if (snapshot.docs.length < _limit) {
          _hasMore = false;
        }

        _lastDocument = snapshot.docs.last;

        final newProducts = snapshot.docs.map((doc) {
          final data = doc.data();

          return ProductModel.fromMap({
            ...data,
            'id': doc.id,
          });
        }).toList();

        for (final product in newProducts) {
          if (_products.every(
            (existing) => existing.id != product.id,
          )) {
            _products.add(product);
          }
        }

        await _cacheProductsLocally();
      }
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CACHE
  // ---------------------------------------------------------------------------

  Future<void> _loadCachedProducts() async {
    if (_companyId == null) return;

    final prefs = await SharedPreferences.getInstance();

    final cacheKey =
        'cached_products_${widget.category}_$_companyId';

    final cachedData = prefs.getString(cacheKey);

    if (cachedData == null || !mounted) return;

    try {
      final decoded =
          List<Map<String, dynamic>>.from(jsonDecode(cachedData));

      final cachedList = decoded
          .map(
            (e) => ProductModel.fromMap(e),
          )
          .toList();

      setState(() {
        _products
          ..clear()
          ..addAll(cachedList);
      });
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
  }

  Future<void> _cacheProductsLocally() async {
    if (_companyId == null) return;

    final prefs = await SharedPreferences.getInstance();

    final cacheKey =
        'cached_products_${widget.category}_$_companyId';

    final encoded = jsonEncode(
      _products.map((p) => p.toMap()).toList(),
    );

    await prefs.setString(cacheKey, encoded);
  }

  Future<void> clearCache(
    String companyId,
    String category,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final cacheKey =
        'cached_products_${category}_$companyId';

    await prefs.remove(cacheKey);
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  bool _fuzzyMatch(
    String text,
    String query,
  ) {
    if (query.isEmpty) return true;

    text = text.toLowerCase();
    query = query.toLowerCase();

    int i = 0;
    int j = 0;

    while (i < text.length && j < query.length) {
      if (text[i] == query[j]) {
        j++;
      }

      i++;
    }

    return j == query.length;
  }

  List<ProductModel> get _filteredProducts {
    if (_searchTerm.isEmpty) {
      return _products;
    }

    final query = _searchTerm.toLowerCase();

    return _products.where((product) {
      final name = product.displayName.toLowerCase();

      final basicMatch = name.contains(query);

      final fuzzyMatch = _fuzzyMatch(
        name,
        query,
      );

      // Finished products can also be searched by product code.
      bool codeMatch = false;

      if (widget.category == 'Finished' || widget.category == 'Other') {
        codeMatch = product.productCode
            .toLowerCase()
            .contains(query);
      }

      return basicMatch || fuzzyMatch || codeMatch;
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchTerm = value.trim();
    });
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Product',
          ),
          content: Text(
            'Are you sure you want to delete "${product.displayName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteProduct(product.id);
    }
  }

  Future<void> _deleteProduct(String docId) async {
    if (_companyId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('products')
          .doc(docId)
          .delete();

      _products.removeWhere(
        (product) => product.id == docId,
      );

      await _cacheProductsLocally();

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deleted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete product: $e',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> _refreshProducts() async {
    if (_companyId == null) return;

    setState(() {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    await clearCache(
      _companyId!,
      widget.category,
    );

    await _fetchProducts();
  }

  // ---------------------------------------------------------------------------
  // PRODUCT HELPERS
  // ---------------------------------------------------------------------------

  String _getRawType(ProductModel product) {
    return product.type.isEmpty ? '-' : product.type;
  }

  String _getGender(ProductModel product) {
    return product.modelGender.isEmpty
        ? '-'
        : product.modelGender;
  }

  String _getProductCode(ProductModel product) {
    return product.productCode.isEmpty
        ? '-'
        : product.productCode;
  }

  String _formatPrice(double price) {
    return '₹ ${price.toStringAsFixed(2)}';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_companyId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final visibleProducts = _filteredProducts;

    return Column(
      children: [
        _buildToolbar(
          visibleCount: visibleProducts.length,
        ),

        const SizedBox(height: 4),

        Expanded(
          child: _buildContent(
            visibleProducts,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TOOLBAR
  // ---------------------------------------------------------------------------

  Widget _buildToolbar({
    required int visibleCount,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        4,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;

          if (isSmall) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchField(),

                const SizedBox(height: 10),

                Row(
                  children: [
                    _buildCountBadge(
                      visibleCount,
                      theme,
                    ),

                    const Spacer(),

                    _buildRefreshButton(),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildSearchField(),
              ),

              const SizedBox(width: 12),

              _buildCountBadge(
                visibleCount,
                theme,
              ),

              const SizedBox(width: 8),

              _buildRefreshButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText:
            'Search ${widget.category.toLowerCase()} products...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon: _searchTerm.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(
                  Icons.close_rounded,
                ),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCountBadge(
    int count,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getProductIcon(),
            size: 18,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 7),
          Text(
            '$count products',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      tooltip: 'Refresh products',
      onPressed: _isLoading
          ? null
          : _refreshProducts,
      icon: const Icon(
        Icons.refresh_rounded,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENT
  // ---------------------------------------------------------------------------

  Widget _buildContent(
    List<ProductModel> products,
  ) {
    if (_products.isEmpty && _isLoading) {
      return _buildLoadingState();
    }

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileTable(products);
        }

        return _buildDesktopTable(products);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP / TABLET TABLE
  // ---------------------------------------------------------------------------

  Widget _buildDesktopTable(
    List<ProductModel> products,
  ) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Fill the available width on large screens.
        // Keep a minimum width for smaller tablet screens.
        final tableWidth = availableWidth >= 1000
            ? availableWidth
            : 900.0;

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: availableWidth < 1000,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: DataTable(
                  headingRowHeight: 52,
                  dataRowMinHeight: 68,
                  dataRowMaxHeight: 78,
                  horizontalMargin: 20,
                  columnSpacing: 32,
                  headingRowColor: WidgetStatePropertyAll(
                    theme.colorScheme.surfaceContainerHighest,
                  ),
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  columns: _buildColumns(),
                  rows: [
                    for (int index = 0;
                        index < products.length;
                        index++)
                      _buildDataRow(
                        products[index],
                        index,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _buildColumns() {
    if (widget.category == 'Raw') {
      return const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Product')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Price')),
        DataColumn(label: Text('Actions')),
      ];
    }

    if (widget.category == 'Finished') {
      return const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Product')),
        DataColumn(label: Text('Gender')),
        DataColumn(label: Text('Product Code')),
        DataColumn(label: Text('Price')),
        DataColumn(label: Text('Actions')),
      ];
    }

    // Other
    return const [
      DataColumn(label: Text('#')),
      DataColumn(label: Text('Product')),
      DataColumn(label: Text('Type')),
      DataColumn(label: Text('Product Code')),
      DataColumn(label: Text('Price')),
      DataColumn(label: Text('Actions')),
    ];
  }

  DataRow _buildDataRow(
    ProductModel product,
    int index,
  ) {
    final theme = Theme.of(context);

    final productCell = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            widget.category == 'Raw'
                ? Icons.settings_input_component_outlined
                : Icons.shopping_bag_outlined,
            size: 19,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 220,
            maxWidth: 420,
          ),
          child: Text(
            product.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final priceCell = Text(
      _formatPrice(product.price),
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
    );

    if (widget.category == 'Raw') {
      return DataRow(
        cells: [
          DataCell(
            Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DataCell(productCell),
          DataCell(
            _buildBadge(
              _getRawType(product),
            ),
          ),
          DataCell(priceCell),
          DataCell(
            _buildActionMenu(product),
          ),
        ],
      );
    }

    if (widget.category == 'Other') {
      return DataRow(
        cells: [
          DataCell(
            Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          DataCell(productCell),

          DataCell(
            _buildBadge(
              _getType(product),
            ),
          ),

          DataCell(
            Text(
              _getProductCode(product),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          DataCell(priceCell),

          DataCell(
            _buildActionMenu(product),
          ),
        ],
      );
    }

    return DataRow(
      cells: [
        DataCell(
          Text(
            '${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(productCell),
        DataCell(
          _buildBadge(
            _getGender(product),
          ),
        ),
        DataCell(
          Text(
            _getProductCode(product),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(priceCell),
        DataCell(
          _buildActionMenu(product),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE TABLE
  // ---------------------------------------------------------------------------

  Widget _buildMobileTable(
    List<ProductModel> products,
  ) {
    final theme = Theme.of(context);

    return Scrollbar(
      controller: _scrollController,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          24,
        ),
        itemCount: products.length +
            ((_hasMore && _isLoading) ? 1 : 0),
        separatorBuilder: (_, __) {
          return const SizedBox(height: 6);
        },
        itemBuilder: (context, index) {
          if (index == products.length && _isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final product = products[index];

          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.category == 'Raw'
                          ? Icons.settings_input_component_outlined
                          : Icons.shopping_bag_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildBadge(
                              widget.category == 'Raw'
                                ? _getRawType(product)
                                : widget.category == 'Finished'
                                    ? _getGender(product)
                                    : _getType(product)
                            ),

                            if ((widget.category == 'Finished' ||
                                widget.category == 'Other') &&
                            product.productCode.isNotEmpty)
                              _buildBadge(
                                product.productCode,
                              ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _formatPrice(product.price),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color:
                                theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  _buildActionMenu(product),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BADGE
  // ---------------------------------------------------------------------------

  Widget _buildBadge(String text) {
    if (text == '-') {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION MENU
  // ---------------------------------------------------------------------------

  Widget _buildActionMenu(
    ProductModel product,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Product actions',
      icon: const Icon(
        Icons.more_vert_rounded,
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showEditProductDialog(product);
            break;

          case 'delete':
            _confirmDelete(product);
            break;
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                ),
                SizedBox(width: 10),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                SizedBox(width: 10),
                Text('Delete'),
              ],
            ),
          ),
        ];
      },
    );
  }

  Future<void> _showEditProductDialog(
    ProductModel product,
  ) async {
    final updatedProduct = await showDialog<ProductModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return EditProductDialog(
          product: product,
          category: widget.category,
          companyId: _companyId!,
        );
      },
    );

    if (updatedProduct == null || !mounted) {
      return;
    }

    final index = _products.indexWhere(
      (item) => item.id == updatedProduct.id,
    );

    if (index != -1) {
      setState(() {
        _products[index] = updatedProduct;
      });

      await _cacheProductsLocally();
    }
  }

  // ---------------------------------------------------------------------------
  // STATES
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading products...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final hasSearch = _searchTerm.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 180;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 8 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 48 : 68,
                  height: compact ? 48 : 68,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasSearch
                        ? Icons.search_off_rounded
                        : Icons.inventory_2_outlined,
                    size: compact ? 24 : 32,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                SizedBox(height: compact ? 8 : 16),

                Text(
                  hasSearch
                      ? 'No products found'
                      : 'No ${widget.category} products yet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: compact ? 3 : 6),

                Text(
                  hasSearch
                      ? 'Try a different product name or code.'
                      : 'Products added to this category will appear here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                if (hasSearch) ...[
                  SizedBox(height: compact ? 8 : 14),

                  OutlinedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear search'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void didUpdateWidget(
    covariant PaginatedProductList oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.category != widget.category) {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
      _isLoading = false;

      _searchController.clear();
      _searchTerm = '';

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
}

class EditProductDialog extends StatefulWidget {
  final ProductModel product;
  final String category;
  final String companyId;

  const EditProductDialog({
    super.key,
    required this.product,
    required this.category,
    required this.companyId,
  });

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _productCodeController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _cavityCountController;

  late String _selectedType;
  late String _selectedGender;
  late String _selectedOtherType;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _loadingModels = false;

  List<Map<String, dynamic>> _rawModels = [];
  List<String?> _cavityModelIds = [];
  List<TextEditingController> _piecesPerCycleControllers = [];

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('products');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.displayName);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _productCodeController = TextEditingController(text: widget.product.productCode);
    _minimumStockController = TextEditingController(text: widget.product.minimumStock.toString());
    _cavityCountController = TextEditingController(text: widget.product.cavityCount.toString().isEmpty ? '1' : widget.product.cavityCount.toString());
    _selectedType = widget.product.type;
    _selectedGender = widget.product.modelGender;
    _selectedOtherType = widget.product.type;

    if (widget.category == 'Other' && widget.product.type == 'Mold') {
      _initializeExistingCavities();
      _loadRawModels();
    }
  }

  void _initializeExistingCavities() {
    final cavities = widget.product.cavities;
    _cavityModelIds = List.generate(
      cavities.length,
      (index) => cavities[index]['modelId']?.toString(),
    );
    if (_cavityModelIds.isEmpty) {
      _cavityModelIds = [null];
    }
    _cavityCountController.text = _cavityModelIds.length.toString();
    _piecesPerCycleControllers = List.generate(
      _cavityModelIds.length,
      (index) => TextEditingController(
        text: _toInt(cavities.length > index ? cavities[index]['piecesPerCycle'] : 1).toString(),
      ),
    );
  }

  Future<void> _loadRawModels() async {
    if (mounted) setState(() => _loadingModels = true);
    try {
      final snapshot = await _productsRef.where('category', isEqualTo: 'Raw').get();
      final grouped = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString() ?? '';
        if (!const ['Black', 'Clear', 'PC'].contains(type)) continue;
        final modelId = data['modelId']?.toString() ?? '';
        final modelName = data['modelName']?.toString() ?? '';
        if (modelId.isEmpty || modelName.isEmpty) continue;

        final model = grouped.putIfAbsent(modelId, () => {
          'modelId': modelId,
          'modelName': modelName,
          'productCode': data['productCode']?.toString() ?? '',
          'variants': <String, dynamic>{},
        });
        final variants = model['variants'] as Map<String, dynamic>;
        variants[type] = {
          'productId': doc.id,
          'productName': data['displayName']?.toString() ?? data['name']?.toString() ?? '',
          'productCode': data['productCode']?.toString() ?? '',
        };
      }

      _rawModels = grouped.values.where((model) {
        final variants = model['variants'] as Map<String, dynamic>;
        return const ['Black', 'Clear', 'PC'].every(variants.containsKey);
      }).toList();
      _rawModels.sort((a, b) => a['modelName'].toString().toLowerCase().compareTo(b['modelName'].toString().toLowerCase()));
    } catch (e) {
      if (mounted) _showMessage('Failed to load Raw models: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Map<String, dynamic>? _findModel(String? id) {
    if (id == null) return null;
    for (final model in _rawModels) {
      if (model['modelId']?.toString() == id) return model;
    }
    return null;
  }

  void _setCavityCount(int count) {
    count = count.clamp(1, 100);
    final oldValues = _piecesPerCycleControllers.map((c) => c.text).toList();
    for (final controller in _piecesPerCycleControllers) controller.dispose();
    _cavityModelIds = List<String?>.generate(
      count,
      (i) => i < _cavityModelIds.length ? _cavityModelIds[i] : null,
    );
    _piecesPerCycleControllers = List.generate(
      count,
      (i) => TextEditingController(text: i < oldValues.length ? oldValues[i] : '1'),
    );
    _cavityCountController.text = count.toString();
  }

  List<Map<String, dynamic>> _buildCavityData() {
    final cavities = <Map<String, dynamic>>[];
    final used = <String>{};

    for (var i = 0; i < _cavityModelIds.length; i++) {
      final modelId = _cavityModelIds[i];
      final model = _findModel(modelId);
      if (modelId == null || model == null) {
        throw Exception('Select a Raw model for Cavity ${i + 1}.');
      }
      if (!used.add(modelId)) {
        throw Exception('${model['modelName']} is already assigned to another cavity.');
      }

      final pieces = int.tryParse(_piecesPerCycleControllers[i].text.trim()) ?? 0;
      if (pieces <= 0) {
        throw Exception('Enter valid Pieces per Cycle for Cavity ${i + 1}.');
      }

      final rawVariants = model['variants'] as Map<String, dynamic>;
      final variants = <String, dynamic>{};
      for (final type in const ['Black', 'Clear', 'PC']) {
        final raw = Map<String, dynamic>.from(rawVariants[type] as Map);
        variants[type] = {
          'productId': raw['productId']?.toString() ?? '',
          'productName': raw['productName']?.toString() ?? '',
          'productCode': raw['productCode']?.toString() ?? '',
        };
      }

      cavities.add({
        'cavityNumber': i + 1,
        'modelId': modelId,
        'modelName': model['modelName'],
        'variants': variants,
        'piecesPerCycle': pieces,
      });
    }
    return cavities;
  }

  Future<void> _saveProduct() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = double.tryParse(_priceController.text.trim());
    final minimumStock = int.tryParse(_minimumStockController.text.trim());
    if (price == null || price < 0 || minimumStock == null || minimumStock < 0) return;

    setState(() => _isSaving = true);
    try {
      final updateData = <String, dynamic>{
        'displayName': _nameController.text.trim(),
        'name': _nameController.text.trim().toLowerCase(),
        'price': price,
        'minimumStock': minimumStock,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.category == 'Raw') {
        updateData['type'] = _selectedType;
      } else if (widget.category == 'Finished') {
        updateData['productCode'] = _productCodeController.text.trim();
        updateData['modelGender'] = _selectedGender;
      } else {
        updateData['type'] = _selectedOtherType;
        updateData['productCode'] = _productCodeController.text.trim();

        if (_selectedOtherType == 'Mold') {
          final count = int.tryParse(_cavityCountController.text.trim()) ?? 0;
          if (count < 1 || _cavityModelIds.length != count) {
            throw Exception('Cavity configuration is incomplete.');
          }
          final cavities = _buildCavityData();
          updateData['cavityCount'] = count;
          updateData['cavities'] = cavities;
        } else {
          updateData['cavityCount'] = 0;
          updateData['cavities'] = [];
        }
      }

      await _productsRef.doc(widget.product.id).update(updateData);

      final updatedProduct = widget.product.copyWith(
        displayName: _nameController.text.trim(),
        price: price,
        minimumStock: minimumStock,
        type: widget.category == 'Raw'
            ? _selectedType
            : widget.category == 'Other'
                ? _selectedOtherType
                : widget.product.type,
        productCode: widget.category == 'Finished' || widget.category == 'Other'
            ? _productCodeController.text.trim()
            : widget.product.productCode,
        modelGender: widget.category == 'Finished' ? _selectedGender : widget.product.modelGender,
        cavityCount: widget.category == 'Other' && _selectedOtherType == 'Mold'
            ? _cavityModelIds.length
            : 0,
        cavities: widget.category == 'Other' && _selectedOtherType == 'Mold'
            ? _buildCavityData()
            : [],
      );

      if (mounted) Navigator.of(context).pop(updatedProduct);
    } catch (e) {
      if (mounted) _showMessage('Failed to update product: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _productCodeController.dispose();
    _minimumStockController.dispose();
    _cavityCountController.dispose();
    for (final controller in _piecesPerCycleControllers) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Product'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price'), validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Enter a valid price' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _minimumStockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum Stock'), validator: (v) => int.tryParse(v?.trim() ?? '') == null ? 'Enter a valid stock' : null),
              if (widget.category == 'Raw') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedType.isEmpty ? null : _selectedType,
                  decoration: const InputDecoration(labelText: 'Material Type'),
                  items: const ['Black', 'Clear', 'PC'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedType = v ?? ''),
                ),
              ],
              if (widget.category == 'Finished') ...[
                const SizedBox(height: 12),
                TextFormField(controller: _productCodeController, decoration: const InputDecoration(labelText: 'Product Code')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedGender.isEmpty ? null : _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const ['Gents', 'Ladies', 'Baby'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedGender = v ?? ''),
                ),
              ],
              if (widget.category == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(controller: _productCodeController, decoration: const InputDecoration(labelText: 'Product Code')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedOtherType.isEmpty ? null : _selectedOtherType,
                  decoration: const InputDecoration(labelText: 'Product Type'),
                  items: const ['Raw Material', 'Mold'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) async {
                    setState(() => _selectedOtherType = v ?? '');
                    if (v == 'Mold') await _loadRawModels();
                  },
                ),
                if (_selectedOtherType == 'Mold') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cavityCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cavity Count'),
                    onChanged: (v) {
                      final count = int.tryParse(v);
                      if (count != null && count >= 1 && count <= 100 && count != _cavityModelIds.length) {
                        setState(() => _setCavityCount(count));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_loadingModels)
                    const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                  else if (_rawModels.isEmpty)
                    const Align(alignment: Alignment.centerLeft, child: Text('No complete Raw models found.'))
                  else
                    ...List.generate(_cavityModelIds.length, _buildCavity),
                ],
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _isSaving ? null : _saveProduct, icon: const Icon(Icons.save_outlined), label: Text(_isSaving ? 'Saving...' : 'Save')),
      ],
    );
  }

  Widget _buildCavity(int index) {
    final model = _findModel(_cavityModelIds[index]);
    final variants = model?['variants'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cavity ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _cavityModelIds[index],
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Model'),
            items: _rawModels.map((m) => DropdownMenuItem(value: m['modelId'].toString(), child: Text('${m['modelName']} • ${m['productCode']}'))).toList(),
            onChanged: (v) => setState(() => _cavityModelIds[index] = v),
          ),
          if (model != null) ...[
            const SizedBox(height: 8),
            ...const ['Black', 'Clear', 'PC'].map((type) {
              final v = Map<String, dynamic>.from(variants[type] as Map);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 55, child: Text(type)),
                  Expanded(child: Text(v['productName']?.toString() ?? '', overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.lock_outline, size: 15),
                ]),
              );
            }),
          ],
          const SizedBox(height: 8),
          TextField(controller: _piecesPerCycleControllers[index], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pieces Per Cycle')),
        ]),
      ),
    );
  }

  int _toInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null));
  }
}