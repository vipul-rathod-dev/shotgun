import 'package:flutter/material.dart';
import 'package:shotgun/screens/supervisor_screens/manage_products_page/widgets/product_list/paginated_product_list.dart';

class ProductTabs extends StatefulWidget {
  const ProductTabs({super.key});

  @override
  State<ProductTabs> createState() => _ProductTabsState();
}

class _ProductTabsState extends State<ProductTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _categories = [
    'Raw',
    'Finished',
    'Packaging',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Products"),
        bottom: TabBar(
          controller: _tabController,
          tabs: _categories.map((cat) => Tab(text: cat)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((cat) {
          return PaginatedProductList(category: cat);
        }).toList(),
      ),
    );
  }
}
