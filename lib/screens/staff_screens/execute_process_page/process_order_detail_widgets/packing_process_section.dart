import 'package\:cloud_firestore/cloud_firestore.dart';

import 'package\:firebase_auth/firebase_auth.dart';

import 'package\:flutter/material.dart';

import 'package\:google_fonts/google_fonts.dart';

class PackingProcessSection extends StatefulWidget {

  final DocumentReference<Map<String, dynamic>> orderRef;

  final String companyId;

  final List products;

  const PackingProcessSection({

    super.key,

    required this.orderRef,

    required this.companyId,

    required this.products,

  });

  @override

  State<PackingProcessSection> createState() =>

      _PackingProcessSectionState();

}

class _PackingProcessSectionState extends State<PackingProcessSection> {

  final Map<String, TextEditingController> _controllers = {};

  final Set<String> _savingProducts = {};

  @override

  void initState() {

    super.initState();

    _initializeControllers();

  }

  void _initializeControllers() {

    for (final product in widget.products) {

      final productId = product["productId"]?.toString();

      if (productId == null || productId.isEmpty) {

        continue;

      }

      _controllers[productId] = TextEditingController();

    }

  }

    @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.orderRef.snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orderSnapshot.hasError) {
          return _errorBox(
            "Unable to load order data.\n${orderSnapshot.error}",
          );
        }

        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return _emptyState(
            Icons.inventory_2_outlined,
            "Order not found",
            "The order could not be loaded.",
          );
        }

        final orderData = orderSnapshot.data!.data() ?? {};
        final Map<String, dynamic> productsPacked =
            Map<String, dynamic>.from(orderData["productsPacked"] ?? {});

        final packingStatus =
            orderData["packingStatus"]?.toString() ?? "Not Started";

        int totalRequired = 0;
        int totalPacked = 0;
        for (final product in widget.products) {
          final productId = product["productId"]?.toString();
          final required = _toInt(product["quantity"]);
          final packedData =
              productId == null ? null : productsPacked[productId];
          final packed =
              packedData is Map ? _toInt(packedData["packed"]) : 0;
          totalRequired += required;
          totalPacked += packed;
        }

        final progress = totalRequired == 0
            ? 0.0
            : (totalPacked / totalRequired).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 900 ? 28.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                        packingStatus: packingStatus,
                        totalRequired: totalRequired,
                        totalPacked: totalPacked,
                        progress: progress,
                      ),
                      const SizedBox(height: 18),
                      _buildProgressSummary(
                        totalRequired: totalRequired,
                        totalPacked: totalPacked,
                        progress: progress,
                      ),
                      const SizedBox(height: 20),
                      _buildProductsHeader(),
                      const SizedBox(height: 12),
                      if (widget.products.isEmpty)
                        _emptyState(
                          Icons.inventory_2_outlined,
                          "No products",
                          "There are no products available for packing.",
                        )
                      else
                        LayoutBuilder(
                          builder: (context, cardConstraints) {
                            final width = cardConstraints.maxWidth;
                            final cardWidth = width >= 950
                                ? (width - 24) / 3
                                : width >= 620
                                    ? (width - 12) / 2
                                    : width;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: List.generate(
                                widget.products.length,
                                (index) {
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _packingCard(
                                      context,
                                      widget.products[index],
                                      productsPacked,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader({
    required String packingStatus,
    required int totalRequired,
    required int totalPacked,
    required double progress,
  }) {
    final completed = packingStatus == "Completed";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3F51B5),
            const Color(0xFF5C6BC0).withOpacity(.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withOpacity(.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Packing Process",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$totalPacked of $totalRequired units packed",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(.78),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 13),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(.18),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.22)),
            ),
            child: Text(
              completed ? "Completed" : packingStatus,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummary({
    required int totalRequired,
    required int totalPacked,
    required double progress,
  }) {
    final remaining = (totalRequired - totalPacked).clamp(0, totalRequired);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(),
      child: Wrap(
        spacing: 28,
        runSpacing: 16,
        children: [
          _summaryMetric(
            Icons.inventory_2_outlined,
            "Required",
            "$totalRequired",
            const Color(0xFF3F51B5),
          ),
          _summaryMetric(
            Icons.check_circle_outline_rounded,
            "Packed",
            "$totalPacked",
            Colors.green,
          ),
          _summaryMetric(
            Icons.pending_actions_rounded,
            "Remaining",
            "$remaining",
            remaining == 0 ? Colors.green : Colors.orange,
          ),
          _summaryMetric(
            Icons.percent_rounded,
            "Progress",
            "${(progress * 100).round()}%",
            const Color(0xFF7E57C2),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.black45,
                fontSize: 10.5,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: const Color(0xFF343741),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductsHeader() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5).withOpacity(.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.view_module_rounded,
                  color: Color(0xFF3F51B5),
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                "Products",
                style: GoogleFonts.poppins(
                  color: const Color(0xFF343741),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          "${widget.products.length} ${widget.products.length == 1 ? 'product' : 'products'}",
          style: GoogleFonts.poppins(
            color: Colors.black45,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _packingCard(
    BuildContext context,
    Map product,
    Map<String, dynamic> productsPacked,
  ) {
    final productId = product["productId"]?.toString();

    if (productId == null || productId.isEmpty) {
      return _invalidProductCard();
    }

    final requiredQty = _toInt(product["quantity"]);
    final savedData = productsPacked[productId] is Map
        ? Map<String, dynamic>.from(productsPacked[productId])
        : <String, dynamic>{};

    final savedPackedQty = _toInt(savedData["packed"]);
    final savedStatus =
        savedData["status"]?.toString() ?? "Not Packed";
    final controller = _controllers[productId]!;

    if (controller.text.isEmpty && savedPackedQty > 0) {
      controller.text = savedPackedQty.toString();
    }

    final remaining = _remainingQty(requiredQty, savedPackedQty);
    final completed = savedStatus == "Completed";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5).withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.view_in_ar_outlined,
                  color: Color(0xFF3F51B5),
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  product["productName"]?.toString() ?? "Unknown Product",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF343741),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              _infoPill(
                Icons.wc_outlined,
                "${product["modelGender"] ?? "-"}",
              ),
              _infoPill(
                Icons.inventory_2_outlined,
                "Required $requiredQty",
              ),
            ],
          ),
          const SizedBox(height: 13),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("companies")
                .doc(widget.companyId)
                .collection("inventory")
                .doc(productId)
                .snapshots(),
            builder: (context, inventorySnapshot) {
              if (inventorySnapshot.connectionState ==
                  ConnectionState.waiting) {
                return _inventoryTile("Inventory", "Loading...");
              }

              if (inventorySnapshot.hasError) {
                return _inventoryTile(
                  "Inventory",
                  "Unavailable",
                  color: Colors.red,
                );
              }

              final inventoryData =
                  inventorySnapshot.data?.data();
              final inventoryQty =
                  _toInt(inventoryData?["availableQuantity"]);

              return _inventoryTile(
                "Available inventory",
                "$inventoryQty units",
                color: inventoryQty >= requiredQty
                    ? Colors.green
                    : Colors.orange,
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _quantityStat(
                    "Packed",
                    "$savedPackedQty",
                    Colors.green,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _quantityStat(
                    "Remaining",
                    "$remaining",
                    remaining == 0 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            "Quantity to pack",
            style: GoogleFonts.poppins(
              color: const Color(0xFF343741),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: _input("Enter packed quantity"),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(child: _packingStatusPill(savedStatus)),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: _savingProducts.contains(productId)
                      ? null
                      : () => _savePacking(
                            product: product,
                            requiredQty: requiredQty,
                            controller: controller,
                          ),
                  icon: _savingProducts.contains(productId)
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 17),
                  label: const Text("Save"),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3F51B5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (completed) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Colors.green,
                ),
                const SizedBox(width: 5),
                Text(
                  "This product is fully packed.",
                  style: GoogleFonts.poppins(
                    color: Colors.green.shade700,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black45),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryTile(
    String label,
    String value, {
    Color color = Colors.black54,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warehouse_outlined, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 10.5,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.black45,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }

  Widget _packingStatusPill(String status) {
    Color color = Colors.grey;
    if (status == "Completed") color = Colors.green;
    if (status == "Partially Packed") color = Colors.orange;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.15)),
      ),
      child: Row(
        children: [
          Icon(
            status == "Completed"
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePacking({

    required Map product,

    required int requiredQty,

    required TextEditingController controller,

  }) async {

    final productId = product["productId"]?.toString();

    if (productId == null || productId.isEmpty) {

      _showMessage(

        "Product ID is missing.",

        isError: true,

      );

      return;

    }

    final packedQty = int.tryParse(controller.text.trim());

    if (packedQty == null) {

      _showMessage(

        "Please enter a valid packed quantity.",

        isError: true,

      );

      return;

    }

    if (packedQty < 0) {

      _showMessage(

        "Packed quantity cannot be negative.",

        isError: true,

      );

      return;

    }

    if (packedQty > requiredQty) {

      _showMessage(

        "Packed quantity cannot be greater than required quantity ($requiredQty).",

        isError: true,

      );

      return;

    }

    setState(() {

      _savingProducts.add(productId);

    });

    try {

      final user = FirebaseAuth.instance.currentUser;

      final status = packedQty == 0

          ? "Not Packed"

          : packedQty >= requiredQty

              ? "Completed"

              : "Partially Packed";

      final remaining = requiredQty - packedQty;

      final packingData = {

        "required": requiredQty,

        "packed": packedQty,

        "remaining": remaining,

        "status": status,

        "updatedAt": FieldValue.serverTimestamp(),

        "updatedByUid": user?.uid,

      };

      debugPrint(

        "Saving packing data for product: $productId",

      );

      debugPrint(

        "Order path: ${widget.orderRef.path}",

      );

      debugPrint(

        "Packing data: $packingData",

      );
      // ---------------------------------------------------*
      // SAVE PRODUCT PACKING DATA*
      // ---------------------------------------------------*

      await widget.orderRef.set(

        {

          "productsPacked": {

            productId: packingData,

          },

        },

        SetOptions(merge: true),

      );
      // ---------------------------------------------------*
      // CHECK WHETHER ALL PRODUCTS ARE COMPLETED*
      // ---------------------------------------------------*

      await _updateOverallPackingStatus(

        currentProductId: productId,

        currentPackingData: packingData,

      );

      if (!mounted) return;

      _showMessage(

        "Packing quantity saved successfully.",

      );

    } on FirebaseException catch (e) {

      debugPrint(

        "Firestore packing error: ${e.code} - ${e.message}",

      );

      if (!mounted) return;

      _showMessage(

        "Firestore error: ${e.code}\n${e.message ?? ""}",

        isError: true,

      );

    } catch (e, stackTrace) {

      debugPrint(

        "Packing save error: $e",

      );

      debugPrint(

        stackTrace.toString(),

      );

      if (!mounted) return;

      _showMessage(

        "Failed to save packing quantity:\n$e",

        isError: true,

      );

    } finally {

      if (mounted) {

        setState(() {

          _savingProducts.remove(productId);

        });

      }

    }

  }

  Future<void> _updateOverallPackingStatus({

    required String currentProductId,

    required Map<String, dynamic> currentPackingData,

  }) async {

    final orderSnapshot = await widget.orderRef.get();

    if (!orderSnapshot.exists) {

      return;

    }

    final orderData = orderSnapshot.data() ?? {};

    final List products =

        List.from(orderData["products"] ?? []);

    final Map<String, dynamic> existingPacked =

        Map<String, dynamic>.from(

      orderData["productsPacked"] ?? {},

    );
      // Make sure the product we just saved is included*
      // in the calculation.*

    existingPacked[currentProductId] = currentPackingData;

    if (products.isEmpty) {

      await widget.orderRef.set(

        {

          "packingStatus": "Completed",

          "orderStatus": "Packing Completed",

          "packingCompletedAt":

              FieldValue.serverTimestamp(),

        },

        SetOptions(merge: true),

      );

      return;

    }

    bool allCompleted = true;

    for (final product in products) {

      final productId = product["productId"]?.toString();

      if (productId == null || productId.isEmpty) {

        continue;

      }

      final requiredQty = _toInt(product["quantity"]);

      final packedData = existingPacked[productId];

      final packedQty = packedData is Map

          ? _toInt(packedData["packed"])

          : 0;

      if (packedQty < requiredQty) {

        allCompleted = false;

        break;

      }

    }

    if (allCompleted) {

      await widget.orderRef.set(

        {

          "packingStatus": "Completed",

          "orderStatus": "Packing Completed",

          "packingCompletedAt":

              FieldValue.serverTimestamp(),

        },

        SetOptions(merge: true),

      );

    } else {

      await widget.orderRef.set(

        {

          "packingStatus": "In Progress",

        },

        SetOptions(merge: true),

      );

    }

  }

  Widget _invalidProductCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _surfaceDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 38,
            color: Colors.orange.shade600,
          ),
          const SizedBox(height: 9),
          Text(
            "Invalid product",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF343741),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            "Product ID is missing.",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.red.shade800,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: _surfaceDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFF343741),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.black45,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  BoxDecoration _surfaceDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4E7EC)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  InputDecoration _input(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      hintStyle: GoogleFonts.poppins(
        color: Colors.black38,
        fontSize: 11,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFF3F51B5),
          width: 1.3,
        ),
      ),
    );
  }

  int _toInt(dynamic value) {

    if (value is int) return value;

    if (value is double) return value.toInt();

    return int.tryParse(

          value?.toString() ?? "0",

        ) ??

        0;

  }

  int _remainingQty(

    int required,

    int packed,

  ) {

    final remaining = required - packed;

    return remaining < 0 ? 0 : remaining;

  }
}