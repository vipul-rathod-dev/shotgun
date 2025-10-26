import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shotgun/screens/staff_screens/order_details/utils/status_color.dart';

class PackingPage extends StatefulWidget {
  const PackingPage({super.key});

  @override
  State<PackingPage> createState() => _PackingPageState();
}

class _PackingPageState extends State<PackingPage> {
  String? selectedStaff;
  bool isLoading = false;
  String? companyId;

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      companyId = prefs.getString('cachedCompanyId');
    });
  }

  Future<void> assignTask(String orderId) async {
    if (selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a staff member first')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'assignedStaff': selectedStaff,
        'orderStatus': 'packing',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task assigned to $selectedStaff ✅'),
          backgroundColor: Colors.green.shade600,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning task: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = ModalRoute.of(context)?.settings.arguments as String?;
    if (orderId == null) {
      return const Scaffold(
        body: Center(child: Text('Invalid order ID')),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          'Packing Stage',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: companyId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(orderId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final order = snapshot.data!.data() as Map<String, dynamic>;
                final status = order['orderStatus'] ?? 'N/A';
                final assignedStaff = order['assignedStaff'];

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order ID: $orderId',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor)),
                      const SizedBox(height: 8),
                      Text('Status: ${status.toString().toUpperCase()}',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: getStatusColor(status))),
                      const SizedBox(height: 20),

                      Text(
                        'Assign Staff Member',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 🔹 Fetch staff users from company namespace
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('companies')
                            .doc(companyId)
                            .collection('users')
                            .where('role', isEqualTo: 'staff')
                            .snapshots(),
                        builder: (context, staffSnapshot) {
                          if (staffSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!staffSnapshot.hasData ||
                              staffSnapshot.data!.docs.isEmpty) {
                            return Text(
                              'No staff users found in this company.',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            );
                          }

                          final staffList = staffSnapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            value: selectedStaff,
                            hint: const Text('Select Staff Member'),
                            items: staffList.map((doc) {
                              final name = doc['name'] ?? 'Unnamed';
                              final email = doc['email'] ?? '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text('$name ($email)',
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedStaff = value);
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // 🔹 Assign Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.assignment_turned_in,
                                  color: Colors.white),
                          label: Text(
                            isLoading ? 'Assigning...' : 'Assign Task',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isLoading ? null : () => assignTask(orderId),
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (assignedStaff != null)
                        Text(
                          'Currently assigned to: $assignedStaff',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
