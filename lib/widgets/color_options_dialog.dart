import 'package:flutter/material.dart';

class ColorOptionsDialog extends StatefulWidget {
  const ColorOptionsDialog({super.key});

  @override
  State<ColorOptionsDialog> createState() => _ColorOptionsDialogState();
}

class _ColorOptionsDialogState extends State<ColorOptionsDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');

  Map<String, int> _colorOptions = {};

  void _addColor() {
    if (_formKey.currentState!.validate()) {
      final color = _colorController.text.trim();
      final qty = int.parse(_quantityController.text.trim());

      setState(() {
        _colorOptions[color] = (_colorOptions[color] ?? 0) + qty;
      });

      _colorController.clear();
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Color Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Form(
            key: _formKey,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(labelText: 'Color Name'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Enter color' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter qty';
                      if (int.tryParse(value) == null) return 'Enter number';
                      if (int.parse(value) <= 0) return 'Qty > 0';
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addColor,
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: _colorOptions.isEmpty
                ? const Center(child: Text('No colors added yet'))
                : ListView(
                    children: _colorOptions.entries
                        .map((e) => ListTile(
                              title: Text(e.key),
                              trailing: Text(e.value.toString()),
                              onLongPress: () {
                                setState(() {
                                  _colorOptions.remove(e.key);
                                });
                              },
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _colorOptions.isEmpty
              ? null
              : () => Navigator.pop(context, _colorOptions),
          child: const Text('Save Colors'),
        ),
      ],
    );
  }
}
