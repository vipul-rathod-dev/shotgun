// Custom TextField Widget

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextField extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool isPassword;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? hintText;

  const CustomTextField({
    super.key,
    required this.controller,
    this.label,
    this.icon,
    this.isPassword = false,
    this.validator,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
    this.textInputAction,
    this.autofillHints,
    this.hintText
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: widget.controller,
        
        obscureText: widget.isPassword ? _obscure : false,
        style: GoogleFonts.poppins(fontSize: 15),
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction ?? TextInputAction.next,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[700]),
          prefixIcon: widget.icon != null
            ? Icon(widget.icon, color: theme.colorScheme.primary)
            : null,
          suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,

          filled: true,
          fillColor: Colors.grey[100],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: widget.hintText
        ),
      ),
    );
  }
}
