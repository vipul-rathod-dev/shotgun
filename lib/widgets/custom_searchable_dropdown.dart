import 'package:flutter/material.dart';

class SearchableDropdown extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String labelText;
  final String keyName; // the key to display (e.g. 'name')
  final void Function(Map<String, dynamic>?) onChanged;
  final Map<String, dynamic>? value;

  const SearchableDropdown({
    super.key,
    required this.items,
    required this.keyName,
    required this.onChanged,
    required this.labelText,
    this.value,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final TextEditingController _controller = TextEditingController();
  late List<Map<String, dynamic>> _filteredItems;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;

    // Pre-fill controller if value exists
    if (widget.value != null && widget.value![widget.keyName] != null) {
      _controller.text = widget.value![widget.keyName].toString();
    }
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = widget.items
          .where((item) => item[widget.keyName]
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.labelText,
            suffixIcon: IconButton(
              icon: Icon(_isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          onChanged: _filterItems,
          readOnly: false,
          onTap: () {
            if (!_isExpanded) {
              setState(() => _isExpanded = true);
            }
          },
        ),
        if (_isExpanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return ListTile(
                  dense: true,
                  title: Text(item[widget.keyName].toString()),
                  onTap: () {
                    widget.onChanged(item);
                    _controller.text = item[widget.keyName].toString();
                    setState(() => _isExpanded = false);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
