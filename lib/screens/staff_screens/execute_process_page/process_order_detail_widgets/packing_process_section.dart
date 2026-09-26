import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.orderRef.snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (orderSnapshot.hasError) {
          return _errorBox(
            "Unable to load order data.\n${orderSnapshot.error}",
          );
        }

        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Text("Order not found");
        }

        final orderData = orderSnapshot.data!.data() ?? {};

        final Map<String, dynamic> productsPacked =
            Map<String, dynamic>.from(
          orderData["productsPacked"] ?? {},
        );

        final packingStatus =
            orderData["packingStatus"]?.toString() ?? "Not Started";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Packing Process",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            _packingStatusCard(packingStatus),

            const SizedBox(height: 16),

            SizedBox(
              height: 290,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 12),
                itemCount: widget.products.length,
                itemBuilder: (context, index) {
                  final product = widget.products[index];

                  return _packingCard(
                    context,
                    product,
                    productsPacked,
                  );
                },
              ),
            ),
          ],
        );
      },
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

    // Populate the input with the Firestore value only when
    // the field is currently empty.
    if (controller.text.isEmpty && savedPackedQty > 0) {
      controller.text = savedPackedQty.toString();
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product["productName"]?.toString() ?? "Unknown Product",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Gender: ${product["modelGender"] ?? "-"}",
            style: GoogleFonts.poppins(fontSize: 13),
          ),

          Text(
            "Required Qty: $requiredQty",
            style: GoogleFonts.poppins(fontSize: 13),
          ),

          const SizedBox(height: 6),

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
                return Text(
                  "Inventory: ...",
                  style: GoogleFonts.poppins(fontSize: 13),
                );
              }

              if (inventorySnapshot.hasError) {
                return Text(
                  "Inventory unavailable",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.red,
                  ),
                );
              }

              final inventoryData =
                  inventorySnapshot.data?.data();

              final inventoryQty =
                  _toInt(inventoryData?["availableQuantity"]);

              return Text(
                "Inventory: $inventoryQty",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          Text(
            "Current Packed: $savedPackedQty",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          Text(
            "Remaining: ${_remainingQty(requiredQty, savedPackedQty)}",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _remainingQty(requiredQty, savedPackedQty) == 0
                  ? Colors.green
                  : Colors.orange,
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 38,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: _input("Qty Packed"),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  savedStatus,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _savingProducts.contains(productId)
                      ? null
                      : () => _savePacking(
                            product: product,
                            requiredQty: requiredQty,
                            controller: controller,
                          ),
                  child: _savingProducts.contains(productId)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Save"),
                ),
              ),
            ],
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

      // ---------------------------------------------------
      // SAVE PRODUCT PACKING DATA
      // ---------------------------------------------------

      await widget.orderRef.set(
        {
          "productsPacked": {
            productId: packingData,
          },
        },
        SetOptions(merge: true),
      );

      // ---------------------------------------------------
      // CHECK WHETHER ALL PRODUCTS ARE COMPLETED
      // ---------------------------------------------------

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

    // Make sure the product we just saved is included
    // in the calculation.
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

  Widget _packingStatusCard(String status) {
    final isCompleted = status == "Completed";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle
                : Icons.inventory_2_outlined,
            size: 20,
            color: isCompleted
                ? Colors.green
                : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            "Packing Status: $status",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invalidProductCard() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: const Center(
        child: Text(
          "Invalid product.\nProduct ID is missing.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.red.shade800,
        ),
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
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
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

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  InputDecoration _input(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade200,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
}