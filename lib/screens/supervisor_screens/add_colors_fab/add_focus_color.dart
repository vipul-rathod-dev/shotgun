import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class AddFocusColor extends StatefulWidget {
  const AddFocusColor({super.key});

  @override
  State<AddFocusColor> createState() => _AddFocusColorState();
}

class _AddFocusColorState extends State<AddFocusColor> {
  final TextEditingController _colorNameController = TextEditingController();
  File? _selectedImage;
  String? _companyId;
  final Set<String> _selectedColors = {};
  final List<String> _materials = ['Black', 'Clear', 'PC'];
  String? _selectedMaterial;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _companyId = prefs.getString('cachedCompanyId'));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _addFocusColor() async {
    final colorName = _colorNameController.text.trim();
    if (colorName.isEmpty) {
      _showSnackBar("Focus Color name cannot be empty", Colors.redAccent);
      return;
    }

    if (_selectedMaterial == null) {
      _showSnackBar("Please select a base material", Colors.redAccent);
      return;
    }

    try {
      final colorData = {
        'name': colorName.trim().toLowerCase(),
        'displayName': "${colorName} - ${_selectedMaterial!}",
        'imagePath': _selectedImage?.path,
        'focusBaseMaterial': _selectedMaterial,
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('focus_colors')
          .add(colorData);

      _colorNameController.clear();
      setState(() {
        _selectedImage = null;
        _selectedMaterial = null;
      });

      _showSnackBar("Focus Color added successfully!", Colors.green);
    } catch (e) {
      _showSnackBar("Error adding focus color: $e", Colors.redAccent);
    }
  }

  Future<void> _deleteFocusColor(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Confirm Deletion"),
            content: const Text(
              "Are you sure you want to delete this focus color?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text("Delete"),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(_companyId)
            .collection('focus_colors')
            .doc(id)
            .delete();

        _showSnackBar("Focus Color deleted", Colors.redAccent);
      } catch (e) {
        _showSnackBar("Error deleting color: $e", Colors.redAccent);
      }
    }
  }

  void _viewImage(File image, String colorName) {
    if (!image.existsSync()) {
      _showSnackBar("Image not found on this device", Colors.redAccent);
      return;
    }

    showGeneralDialog(
      context: context,
      barrierLabel: "View Image",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, _, __) {
        final curvedValue = Curves.easeOut.transform(anim.value);
        return Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curvedValue) * 80),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Text(
                      colorName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        image,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.share_outlined),
                      label: Text("$colorName 👆"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          () => Share.shareFiles([
                            image.path,
                          ], text: "$colorName 👆"),
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

  Future<void> _exportSelectedToPDF(
    List<Map<String, dynamic>> selectedColors,
  ) async {
    try {
      _showSnackBar("Generating PDF...", Colors.blueAccent);
      final pdf = pw.Document();

      for (var color in selectedColors) {
        final imagePath = color['imagePath'] as String?;
        final colorName = color['name'] ?? '';

        pw.Widget imageWidget;
        if (imagePath != null && File(imagePath).existsSync()) {
          final image = pw.MemoryImage(File(imagePath).readAsBytesSync());
          imageWidget = pw.Image(
            image,
            width: 400,
            height: 400,
            fit: pw.BoxFit.contain,
          );
        } else {
          imageWidget = pw.Container(
            height: 300,
            alignment: pw.Alignment.center,
            child: pw.Text(
              "No Image Found",
              style: pw.TextStyle(fontSize: 16, color: PdfColors.grey),
            ),
          );
        }

        pdf.addPage(
          pw.Page(
            build:
                (context) => pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      colorName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    imageWidget,
                  ],
                ),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/FocusColors.pdf");
      await file.writeAsBytes(await pdf.save());

      _showSnackBar("PDF saved at ${file.path}", Colors.green);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      _showSnackBar("Error generating PDF: $e", Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  void dispose() {
    _colorNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Focus Colors'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1976D2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      floatingActionButton:
          _selectedColors.isEmpty
              ? null
              : FloatingActionButton.extended(
                onPressed: () async {
                  final snapshot =
                      await FirebaseFirestore.instance
                          .collection('companies')
                          .doc(_companyId)
                          .collection('focus_colors')
                          .get();

                  final selectedDocs =
                      snapshot.docs
                          .where((doc) => _selectedColors.contains(doc.id))
                          .map((doc) => doc.data())
                          .toList();

                  await _exportSelectedToPDF(selectedDocs);
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text("Export to PDF"),
                backgroundColor: Colors.blueAccent,
              ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add Color Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _colorNameController,
                          decoration: InputDecoration(
                            labelText: "Focus Color Name",
                            prefixIcon: const Icon(Icons.palette_outlined),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.image_outlined,
                                color: Colors.blueAccent,
                              ),
                              onPressed: _pickImage,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedMaterial,
                          decoration: InputDecoration(
                            labelText: "Base Material",
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items:
                              _materials
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) => setState(() => _selectedMaterial = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _addFocusColor,
                    icon: const Icon(Icons.add),
                    label: const Text("Add"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // List of Colors
            Expanded(
              child:
                  _companyId == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('companies')
                                .doc(_companyId)
                                .collection('focus_colors')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text("No focus colors added yet."),
                            );
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final imagePath = data['imagePath'] as String?;
                              final isSelected = _selectedColors.contains(
                                doc.id,
                              );

                              return GestureDetector(
                                onLongPress: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedColors.remove(doc.id);
                                    } else {
                                      _selectedColors.add(doc.id);
                                    }
                                  });
                                },
                                onTap: () {
                                  if (_selectedColors.isNotEmpty) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedColors.remove(doc.id);
                                      } else {
                                        _selectedColors.add(doc.id);
                                      }
                                    });
                                  } else if (imagePath != null) {
                                    final file = File(imagePath);
                                    if (file.existsSync()) {
                                      _viewImage(file, data['name']);
                                    } else {
                                      _showSnackBar(
                                        "Image not found",
                                        Colors.red,
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Colors.blue.shade50
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    leading:
                                        imagePath != null &&
                                                File(imagePath).existsSync()
                                            ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.file(
                                                File(imagePath),
                                                width: 55,
                                                height: 55,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                            : const CircleAvatar(
                                              backgroundColor: Color(
                                                0xFFE3F2FD,
                                              ),
                                              child: Icon(
                                                Icons.palette_outlined,
                                                color: Color(0xFF1976D2),
                                              ),
                                            ),
                                    title: Text(
                                      data['displayName'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      data['focusBaseMaterial'] != null &&
                                              data['focusBaseMaterial']
                                                  .toString()
                                                  .isNotEmpty
                                          ? "Material: ${data['focusBaseMaterial']}"
                                          : "Material: N/A",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed:
                                          () => _deleteFocusColor(doc.id),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
