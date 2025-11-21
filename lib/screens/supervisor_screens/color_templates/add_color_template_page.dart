import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/widgets/custom_searchable_dropdown.dart';

class AddColorTemplatePage extends StatefulWidget {
  final String? templateId;
  final Map<String, dynamic>? initialData;

const AddColorTemplatePage({super.key, this.templateId, this.initialData});


  @override
  State<AddColorTemplatePage> createState() => _AddColorTemplatePageState();
}

class _AddColorTemplatePageState extends State<AddColorTemplatePage> {
  final nameController = TextEditingController();
  final blackQtyController = TextEditingController();
  final clearQtyController = TextEditingController();
  final pcQtyController = TextEditingController();
  bool showCards = false;
  String? selectedGender;

  final List<Map<String, String>> genderOptions = [
    {"id": "gents", "name": "Gents"},
    {"id": "ladies", "name": "Ladies"},
    {"id": "baby", "name": "Baby"},
  ];

  late String companyId;
  bool loading = true;
  bool get isEditing => widget.templateId != null;

  List<Map<String, dynamic>> cards = [];

  @override
  void initState() {
    super.initState();
    _loadCompanyAndColors();

    blackQtyController.addListener(_checkQtyFields);
    clearQtyController.addListener(_checkQtyFields);
    pcQtyController.addListener(_checkQtyFields);
  }

  void _checkQtyFields() {
    if (isEditing) return; // Prevent card regeneration in edit mode

    final b = int.tryParse(blackQtyController.text) ?? 0;
    final c = int.tryParse(clearQtyController.text) ?? 0;
    final p = int.tryParse(pcQtyController.text) ?? 0;

    final total = b + c + p;

    if (total == 0) {
      setState(() {
        showCards = false;
        cards = [];
      });
      return;
    }

    setState(() {
      showCards = true;

      cards = [];

      // Add BLACK cards
      for (int i = 0; i < b; i++) {
        cards.add({
          "focusBaseMaterial": "Black",
          "focusColor": null,
          "focusColorId": null,
          "templeBaseMaterial": "Black",
          "templeColor": null,
          "templeColorId": null,
        });
      }

      // Add CLEAR cards
      for (int i = 0; i < c; i++) {
        cards.add({
          "focusBaseMaterial": "Clear",
          "focusColor": null,
          "focusColorId": null,
          "templeBaseMaterial": "Clear",
          "templeColor": null,
          "templeColorId": null,
        });
      }

      // Add PC cards
      for (int i = 0; i < p; i++) {
        cards.add({
          "focusBaseMaterial": "PC",
          "focusColor": null,
          "focusColorId": null,
          "templeBaseMaterial": "PC",
          "templeColor": null,
          "templeColorId": null,
        });
      }
    });
  }

  Future<void> _loadCompanyAndColors() async {
    final prefs = await SharedPreferences.getInstance();
    companyId = prefs.getString("cachedCompanyId") ?? "";

    if (companyId.isEmpty) companyId = "unknown_company";

    await _fetchFocusColors();
    await _fetchTempleColors();

    // If editing, prefill fields
    if (widget.initialData != null) {
      _populateFromInitialData(widget.initialData!);
    }


    setState(() => loading = false);
  }

  List<Map<String, String>> focusColors = [];
  List<Map<String, String>> templeColors = [];

  Future<void> _fetchFocusColors() async {
    final snap = await FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("focus_colors")
        .get();

    focusColors = snap.docs
        .map((d) => {
              "id": d.id,
              "name": (d.data()["name"] ?? "").toString().trim(),
            })
        .toList();
  }

  Future<void> _fetchTempleColors() async {
    final snap = await FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("temple_colors")
        .get();

    templeColors = snap.docs
        .map((d) => {
              "id": d.id,
              "name": (d.data()["name"] ?? "").toString().trim(),
            })
        .toList();
  }

  void _populateFromInitialData(Map<String, dynamic> doc) {
    try {
      // Template name
      nameController.text = (doc["name"] ?? "").toString();

      // Extract gender
      final productCustomizations =
          doc["productCustomizations"] as Map<String, dynamic>? ?? {};
      if (productCustomizations.isEmpty) return;

      final genderKey = productCustomizations.keys.first;
      selectedGender = genderKey;
      print("genderKey detected = $genderKey");


      final combos = productCustomizations[genderKey] as List? ?? [];

      List<Map<String, dynamic>> expandedCards = [];

      for (var c in combos) {
        int qty = int.tryParse(c["focusQty"].toString()) ?? 1;

        for (int i = 0; i < qty; i++) {
          expandedCards.add({
            "focusBaseMaterial": c["focusBaseMaterial"] ?? "",
            "focusColor": c["focusColor"],
            "focusColorId": c["focusColorId"],
            "templeBaseMaterial": c["templeBaseMaterial"] ?? "",
            "templeColor": c["templeColor"],
            "templeColorId": c["templeColorId"],
          });
        }
      }

      cards = expandedCards;

      // show UI cards
      showCards = cards.isNotEmpty;

      // AUTO-PREFILL QTY FIELDS (but they remain disabled)
      int black = 0;
      int clear = 0;
      int pc = 0;

      for (var card in expandedCards) {
        final focusBase = card["focusBaseMaterial"]?.toString().toLowerCase() ?? "";
        final templeBase = card["templeBaseMaterial"]?.toString().toLowerCase() ?? "";
        final base = focusBase == templeBase ? focusBase : "";

        if (base == "black") black++;
        if (base == "clear") clear++;
        if (base == "pc") pc++;
      }

      blackQtyController.text = black.toString();
      clearQtyController.text = clear.toString();
      pcQtyController.text = pc.toString();

      setState(() {});
    } catch (e) {
      debugPrint("Error populating initial data: $e");
    }
  }

  Future<void> _saveTemplate() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Template name is required")),
      );
      return;
    }

    if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Model Gender")),
      );
      return;
    }

    if (!showCards || cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter quantities to generate color combinations")),
      );
      return;
    }

    // Validate each card has selections
    for (var card in cards) {
      if (card["focusColor"] == null || card["templeColor"] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select focus and temple colors for all cards")),
        );
        return;
      }
    }

    // 🔥 NO MERGING — each card is treated individually
    final List<Map<String, dynamic>> combosToSave = cards.map((card) {
      return {
        "focusBaseMaterial": card["focusBaseMaterial"],
        "focusColor": card["focusColor"],
        "focusColorId": card["focusColorId"],
        "focusQty": 1,
        "templeBaseMaterial": card["templeBaseMaterial"],
        "templeColor": card["templeColor"],
        "templeColorId": card["templeColorId"],
        "templeQty": 1,
      };
    }).toList();

    // Get gender name
    final genderEntry = genderOptions.firstWhere(
      (g) => g["id"] == selectedGender,
      orElse: () => {"id": selectedGender!, "name": selectedGender!},
    );

    final genderName = genderEntry["name"] ?? selectedGender;

    final data = {
      "name": "${nameController.text.trim()} - $genderName",
      "createdAt": FieldValue.serverTimestamp(),
      "status": "active",
      "productCustomizations": {
        selectedGender!: combosToSave,
      },
    };

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection("companies")
          .doc(companyId)
          .collection("color_templates");

      if (widget.templateId != null) {
        await collectionRef.doc(widget.templateId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Template updated successfully")),
        );
      } else {
        await collectionRef.add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Template saved successfully")),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving template: $e")),
      );
    }
  }

  // Future<void> _saveTemplate() async {
  //   if (nameController.text.trim().isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Template name is required")),
  //     );
  //     return;
  //   }
  //   if (selectedGender == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Please select Model Gender")),
  //     );
  //     return;
  //   }
  //   if (!showCards || cards.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Enter quantities to generate color combinations")),
  //     );
  //     return;
  //   }
  //   // Validate each card has selections
  //   for (var card in cards) {
  //     if (card["focusColor"] == null || card["templeColor"] == null) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("Please select focus and temple colors for all cards")),
  //       );
  //       return;
  //     }
  //   }
  //   // 🔥 MERGE DUPLICATES
  //   final Map<String, Map<String, dynamic>> merged = {};
  //   for (var card in cards) {
  //     final key =
  //         "${card["focusBaseMaterial"]}_${card["focusColorId"]}_${card["templeBaseMaterial"]}_${card["templeColorId"]}";
  //     if (!merged.containsKey(key)) {
  //       merged[key] = {
  //         "focusBaseMaterial": card["focusBaseMaterial"],
  //         "focusColor": card["focusColor"],
  //         "focusColorId": card["focusColorId"],
  //         "focusQty": 1, // initial count
  //         "templeBaseMaterial": card["templeBaseMaterial"],
  //         "templeColor": card["templeColor"],
  //         "templeColorId": card["templeColorId"],
  //         "templeQty": 1, // initial count
  //       };
  //     } else {
  //       merged[key]!["focusQty"] += 1; // increment count
  //       merged[key]!["templeQty"] += 1; // increment count
  //     }
  //   }
  //   if (merged.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("No valid color combinations to save")),
  //     );
  //     return;
  //   }
  //   // Get human-readable gender name for display
  //   final genderEntry = genderOptions.firstWhere((g) => g["id"] == selectedGender, orElse: () => {"id": selectedGender!, "name": selectedGender!});
  //   final genderName = genderEntry["name"] ?? selectedGender;
  //   final data = {
  //     "name": "${nameController.text.trim()} - $genderName",
  //     "createdAt": FieldValue.serverTimestamp(),
  //     "status": "active",
  //     // keep the id as the key (e.g. "gents") and the merged list as value
  //     "productCustomizations": {selectedGender!: merged.values.toList()},
  //   };
  //   try {
  //     final collectionRef = FirebaseFirestore.instance
  //         .collection("companies")
  //         .doc(companyId)
  //         .collection("color_templates");
  //     if (widget.templateId != null) {
  //       // Update existing doc
  //       await collectionRef.doc(widget.templateId).update(data);
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template updated successfully")));
  //     } else {
  //       // Create new
  //       await collectionRef.add(data);
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template saved successfully")));
  //     }
  //     Navigator.pop(context, true); // signal success to caller
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving template: $e")));
  //   }
  // }

  @override
  void dispose() {
    nameController.dispose();
    blackQtyController.dispose();
    clearQtyController.dispose();
    pcQtyController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Color Templates"),
        centerTitle: true,
        elevation: 0,
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEditing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Editing Template Mode",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _sectionLabel("Template Name"),

              TextField(
                controller: nameController,
                decoration: _inputDecoration("Enter template name"),
              ),

              const SizedBox(height: 20),

              _sectionLabel("Model Gender"),

              SearchableDropdown(
                labelText: "Model Gender",
                keyName: "name",
                items: genderOptions,
                value: selectedGender == null
                  ? null
                  : genderOptions.where((g) => g["id"] == selectedGender).isNotEmpty
                      ? genderOptions.firstWhere((g) => g["id"] == selectedGender)
                      : null,
                onChanged: (value) {
                  setState(() {
                    selectedGender = value?["id"];
                  });
                },
              ),

              const SizedBox(height: 20),

              _sectionLabel("Base Material Quantities"),

              Row(
                children: [
                  _qtyField("Black Qty", blackQtyController),
                  const SizedBox(width: 12),
                  _qtyField("Clear Qty", clearQtyController),
                  const SizedBox(width: 12),
                  _qtyField("PC Qty", pcQtyController),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                "Color cards will appear automatically based on the quantities above.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 30),

              // DYNAMIC CARDS LIST WITH ANIMATION
              if (showCards)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    itemBuilder: (context, index) =>
                        _animatedCardWrapper(_buildColorCard(index)),
                  ),
                ),

              const SizedBox(height: 30),

              _animatedSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animatedCardWrapper(Widget child) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }


  Widget _animatedSaveButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: (selectedGender != null && showCards && cards.isNotEmpty) ? 1 : 0.5,
      child: ElevatedButton(
        onPressed: (selectedGender != null && showCards && cards.isNotEmpty)
            ? _saveTemplate
            : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: Colors.blue,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          "Save Color Template",
          style: TextStyle(fontSize: 17, color: Colors.white),
        ),
      ),
    );
  }


  Widget _qtyField(String label, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        enabled: !isEditing, // disable in edit mode
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isEditing ? Colors.grey.shade300 : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }


  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }


  // CARD WIDGET
  Widget _buildColorCard(int index) {
    final item = cards[index];

    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${item["focusBaseMaterial"]} – Color Combination",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 18),

            SearchableDropdown(
              labelText: "Focus Color",
              keyName: "name",
              items: focusColors,
              value: item["focusColorId"] != null
                ? focusColors.where((c) => c["id"] == item["focusColorId"]).isNotEmpty
                    ? focusColors.firstWhere((c) => c["id"] == item["focusColorId"])
                    : null
                : null,
              onChanged: (selected) {
                if (selected != null) {
                  setState(() {
                    item["focusColor"] = selected["name"];
                    item["focusColorId"] = selected["id"];
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            SearchableDropdown(
              labelText: "Temple Color",
              keyName: "name",
              items: templeColors,
              value: item["templeColorId"] != null
                ? templeColors.where((c) => c["id"] == item["templeColorId"]).isNotEmpty
                    ? templeColors.firstWhere((c) => c["id"] == item["templeColorId"])
                    : null
                : null,
              onChanged: (selected) {
                if (selected != null) {
                  setState(() {
                    item["templeColor"] = selected["name"];
                    item["templeColorId"] = selected["id"];
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
