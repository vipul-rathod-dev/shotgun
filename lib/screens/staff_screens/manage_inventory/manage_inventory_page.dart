import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/staff_screens/manage_inventory/widgets/search_bar.dart';
import 'inventory_controller.dart';
import 'widgets/add_inventory_dialog.dart';
import 'widgets/delete_confirmation_dialog.dart';
import 'widgets/product_card.dart';

class ManageProductPage1 extends StatelessWidget {
  const ManageProductPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) =>
              InventoryController()
                ..fetchProducts()
                ..loadSuppliers(),
      child: const _ManageInventoryBody(),
    );
  }
}

class _ManageInventoryBody extends StatelessWidget {
  const _ManageInventoryBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Inventory'),
        backgroundColor: Colors.lightBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamed(context, '/staff'),
        ),
      ),
      body: Column(
        children: [
          InventorySearchBar(onSearch: controller.onSearchChanged),
          Expanded(
            child:
                controller.products.isEmpty && controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : controller.products.isEmpty
                    ? const Center(child: Text('No products found.'))
                    : ListView.builder(
                      itemCount: controller.products.length,
                      itemBuilder: (context, index) {
                        final doc = controller.products[index];
                        return ProductCard(
                          doc: doc,
                          onAddInventory:
                              () => showAddInventoryDialog(
                                context,
                                productId: doc.id,
                                productName: doc['name'],
                                moldingSuppliers: controller.moldingSuppliers,
                                drummingSuppliers: controller.drummingSuppliers,
                              ),
                          onDelete:
                              () => showDeleteConfirmationDialog(
                                context,
                                productName: doc['name'],
                                onConfirm:
                                    () => controller.deleteProduct(doc.id),
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
