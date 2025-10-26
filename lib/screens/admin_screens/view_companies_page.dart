import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewCompaniesPage extends StatelessWidget {
  const ViewCompaniesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final companiesRef = FirebaseFirestore.instance.collection('companies');

    return Scaffold(
      appBar: AppBar(
        title: Text('Existing Companies', style: GoogleFonts.poppins()),
        backgroundColor: Colors.orangeAccent.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: companiesRef.orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading companies'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No companies found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final company = docs[index].data() as Map<String, dynamic>;
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(company['name'] ?? 'Unnamed Company',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    company['address'] ?? 'No address provided',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
