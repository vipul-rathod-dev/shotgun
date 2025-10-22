import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final void Function(DateTime) onDateSelected;

  const DatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: selectedDate == null
            ? ''
            : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
      ),
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) onDateSelected(picked);
          },
        ),
      ),
      validator: (value) =>
          selectedDate == null ? 'Please select $label' : null,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onDateSelected(picked);
      },
    );
  }
}










// import 'package:flutter/material.dart';

// class DatePickerField extends StatelessWidget {
//   final String label;
//   final DateTime? selectedDate;
//   final void Function(DateTime) onDateSelected;

//   const DatePickerField({
//     required this.label,
//     required this.selectedDate,
//     required this.onDateSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return TextFormField(
//       readOnly: true,
//       controller: TextEditingController(
//         text: selectedDate == null
//             ? ''
//             : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
//       ),
//       decoration: InputDecoration(
//         labelText: label,
//         border: const OutlineInputBorder(),
//         suffixIcon: const Icon(Icons.calendar_today),
//       ),
//       validator: (value) =>
//           selectedDate == null ? 'Please select $label' : null,
//       onTap: () async {
//         final picked = await showDatePicker(
//           context: context,
//           initialDate: selectedDate ?? DateTime.now(),
//           firstDate: DateTime(2000),
//           lastDate: DateTime(2100),
//         );
//         if (picked != null) onDateSelected(picked);
//       },
//     );
//   }
// }
