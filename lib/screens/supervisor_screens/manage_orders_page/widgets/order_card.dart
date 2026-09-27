import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:shotgun/screens/supervisor_screens/manage_orders_page/add_orders_page.dart';

import 'package:shotgun/screens/supervisor_screens/manage_orders_page/widgets/create_task_page.dart';

import '../helpers/status_color.dart';

import 'order_details_insights/order_details_insights_page.dart';

class OrderCard extends StatelessWidget {

  final String orderId;

  final Map<String, dynamic> orderData;

  const OrderCard({

    super.key,

    required this.orderId,

    required this.orderData,

  });

  @override

  Widget build(BuildContext context) {

    final id = orderData['orderNumber']?.toString() ?? 'N/A';

    final customer =

        orderData['customerName']?.toString() ?? 'Unknown';

    final Timestamp? timestamp = orderData['orderDate'];

    final date = timestamp != null

        ? DateFormat.yMMMd().format(timestamp.toDate())

        : 'No date';

    final orderType = orderData['orderType']?.toString() ?? 'N/A';

    final status =

        orderData['orderStatus']?.toString() ?? 'Yet to Start';

    final statusColor = StatusColor.fromStatus(status);
    final isCompleted = status.trim().toLowerCase() == 'completed';

    final currentUser = FirebaseAuth.instance.currentUser;

    final createdByUid = orderData['createdByUid'];

    final isCreatedByCurrentUser =

        currentUser?.uid == createdByUid;

    return Card(

      elevation: 2,

      margin: const EdgeInsets.symmetric(

        vertical: 6,

        horizontal: 4,

      ),

      shape: RoundedRectangleBorder(

        borderRadius: BorderRadius.circular(14),

      ),

      clipBehavior: Clip.antiAlias,

      child: Padding(

        padding: const EdgeInsets.fromLTRB(

          14,

          12,

          10,

          10,

        ),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // --------------------------------------------------

            // HEADER

            // --------------------------------------------------

            Row(

              crossAxisAlignment: CrossAxisAlignment.center,

              children: [

                Container(

                  width: 38,

                  height: 38,

                  decoration: BoxDecoration(

                    color: Colors.blue.withOpacity(0.10),

                    borderRadius: BorderRadius.circular(10),

                  ),

                  child: const Icon(

                    Icons.receipt_long,

                    color: Colors.blue,

                    size: 21,

                  ),

                ),

                const SizedBox(width: 10),

                // Order number

                Expanded(

                  child: Text(

                    id,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(

                      fontSize: 16,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                ),

                // More menu

                if (isCompleted) ...[


                  Container(


                    padding: const EdgeInsets.symmetric(


                      horizontal: 9,


                      vertical: 6,


                    ),


                    decoration: BoxDecoration(


                      color: Colors.green.withOpacity(0.10),


                      borderRadius: BorderRadius.circular(20),


                      border: Border.all(


                        color: Colors.green.withOpacity(0.25),


                      ),


                    ),


                    child: Row(


                      mainAxisSize: MainAxisSize.min,


                      children: [


                        const Icon(


                          Icons.check_circle,


                          color: Colors.green,


                          size: 16,


                        ),


                        const SizedBox(width: 5),


                        const Text(


                          'Completed',


                          style: TextStyle(


                            color: Colors.green,


                            fontSize: 11.5,


                            fontWeight: FontWeight.w700,


                          ),


                        ),


                      ],


                    ),


                  ),


                ] else


                  _buildMoreMenu(context),
              ],

            ),

            const SizedBox(height: 12),

            // --------------------------------------------------

            // CUSTOMER

            // --------------------------------------------------

            _InfoRow(

              icon: Icons.person_outline,

              label: 'Customer',

              value: customer,

            ),

            const SizedBox(height: 7),

            // --------------------------------------------------

            // DATE

            // --------------------------------------------------

            _InfoRow(

              icon: Icons.calendar_today_outlined,

              label: 'Date',

              value: date,

            ),

            const SizedBox(height: 9),

            _InfoRow(

              icon: Icons.category_outlined,

              label: 'Order Type',

              value: orderType,

            ),

            const SizedBox(height: 9),

            // --------------------------------------------------

            // STATUS

            // --------------------------------------------------

            Row(

              crossAxisAlignment: CrossAxisAlignment.center,

              children: [

                const Icon(

                  Icons.circle,

                  size: 9,

                  color: Colors.grey,

                ),

                const SizedBox(width: 7),

                const Text(

                  'Status:',

                  style: TextStyle(

                    fontSize: 13,

                    fontWeight: FontWeight.w600,

                  ),

                ),

                const SizedBox(width: 6),

                Expanded(

                  child: Align(

                    alignment: Alignment.centerLeft,

                    child: Container(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 9,

                        vertical: 4,

                      ),

                      decoration: BoxDecoration(

                        color: statusColor.withOpacity(0.10),

                        borderRadius: BorderRadius.circular(20),

                      ),

                      child: Text(

                        status,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(

                          color: statusColor,

                          fontSize: 12,

                          fontWeight: FontWeight.w700,

                        ),

                      ),

                    ),

                  ),

                ),

              ],

            ),

            const SizedBox(height: 12),

            // Divider

            Divider(

              height: 1,

              color: Colors.grey.shade200,

            ),

            const SizedBox(height: 8),

            // --------------------------------------------------

            // ACTIONS

            // --------------------------------------------------

            Row(

              children: [

                // VIEW

                Expanded(

                  child: _ActionButton(

                    icon: Icons.visibility_outlined,

                    label: 'View',

                    color: Colors.blue,

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>

                              OrderDetailsInsightsPage(

                            orderId: orderId,

                          ),

                        ),

                      );

                    },

                  ),

                ),

                if (isCreatedByCurrentUser) ...[

                  const SizedBox(width: 6),

                  // EDIT

                  Expanded(

                    child: _ActionButton(

                      icon: Icons.edit_outlined,

                      label: 'Edit',

                      color: Colors.orange,

                      onTap: () {

                        Navigator.push(

                          context,

                          MaterialPageRoute(

                            builder: (_) => AddOrdersPage(

                              isEditMode: true,

                              orderId: orderId,

                            ),

                          ),

                        );

                      },

                    ),

                  ),

                  const SizedBox(width: 6),

                  // DELETE

                  Expanded(

                    child: _ActionButton(

                      icon: Icons.delete_outline,

                      label: 'Delete',

                      color: Colors.red,

                      onTap: () => _deleteOrder(context),

                    ),

                  ),

                ],

              ],

            ),

          ],

        ),

      ),

    );

  }

  // ============================================================

  // MORE MENU

  // ============================================================

  Widget _buildMoreMenu(BuildContext context) {

    final currentStatus =

        orderData['orderStatus']?.toString().toLowerCase() ?? '';


    if (currentStatus == 'completed') {

      return const SizedBox.shrink();

    }


    return PopupMenuButton<String>(

      tooltip: 'More',

      padding: EdgeInsets.zero,

      icon: const Icon(Icons.more_vert),

      shape: RoundedRectangleBorder(

        borderRadius: BorderRadius.circular(12),

      ),

      onSelected: (value) {

        if (value == 'create_task') {

          final currentStatus =

              orderData['orderStatus']?.toString().toLowerCase() ?? '';


          if (currentStatus == 'completed') {

            return;

          }


          Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) => CreateTaskPage(

                orderId: orderId,

                orderData: orderData,

              ),

            ),

          );

        }

      },

      itemBuilder: (context) => const [

        PopupMenuItem(

          value: 'create_task',

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(

                Icons.task_alt,

                size: 18,

              ),

              SizedBox(width: 8),

              Text('Create Task'),

            ],

          ),

        ),

      ],

    );

  }

  // ============================================================

  // DELETE ORDER

  // ============================================================

  Future<void> _deleteOrder(BuildContext context) async {

    final confirm = await showDialog<bool>(

      context: context,

      builder: (dialogContext) => AlertDialog(

        title: const Text('Delete Order'),

        content: const Text(

          'Are you sure you want to delete this order?',

        ),

        actions: [

          TextButton(

            onPressed: () {

              Navigator.pop(dialogContext, false);

            },

            child: const Text('Cancel'),

          ),

          ElevatedButton(

            style: ElevatedButton.styleFrom(

              backgroundColor: Colors.red,

              foregroundColor: Colors.white,

            ),

            onPressed: () {

              Navigator.pop(dialogContext, true);

            },

            child: const Text('Delete'),

          ),

        ],

      ),

    );

    if (confirm != true) return;

    try {

      final prefs = await SharedPreferences.getInstance();

      final companyId =

          prefs.getString('cachedCompanyId');

      final currentUser =

          FirebaseAuth.instance.currentUser;

      if (companyId == null || currentUser == null) {

        throw Exception(

          'Missing user or company information.',

        );

      }

      final orderRef = FirebaseFirestore.instance

          .collection('companies')

          .doc(companyId)

          .collection('orders')

          .doc(orderId);

      final orderSnap = await orderRef.get();

      if (!orderSnap.exists) {

        throw Exception('Order not found.');

      }

      final data = orderSnap.data()!;

      final createdBy = data['createdByUid'];

      if (createdBy != currentUser.uid) {

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text(

              'You can only delete orders you created.',

            ),

            backgroundColor: Colors.red,

          ),

        );

        return;

      }

      await orderRef.delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text(

            'Order deleted successfully',

          ),

        ),

      );

    } catch (e) {

      debugPrint(

        'Delete order failed: $e',

      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            'Failed to delete order: $e',

          ),

          backgroundColor: Colors.red,

        ),

      );

    }

  }

}

// ================================================================

// INFO ROW

// ================================================================

class _InfoRow extends StatelessWidget {

  final IconData icon;

  final String label;

  final String value;

  const _InfoRow({

    required this.icon,

    required this.label,

    required this.value,

  });

  @override

  Widget build(BuildContext context) {

    return Row(

      children: [

        Icon(

          icon,

          size: 17,

          color: Colors.grey.shade600,

        ),

        const SizedBox(width: 8),

        Text(

          '$label:',

          style: const TextStyle(

            fontSize: 13,

            fontWeight: FontWeight.w600,

          ),

        ),

        const SizedBox(width: 5),

        Expanded(

          child: Text(

            value,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(

              fontSize: 13,

              color: Colors.grey.shade700,

            ),

          ),

        ),

      ],

    );

  }

}

// ================================================================

// ACTION BUTTON

// ================================================================

class _ActionButton extends StatelessWidget {

  final IconData icon;

  final String label;

  final Color color;

  final VoidCallback onTap;

  const _ActionButton({

    required this.icon,

    required this.label,

    required this.color,

    required this.onTap,

  });

  @override

  Widget build(BuildContext context) {

    return SizedBox(

      height: 38,

      child: OutlinedButton.icon(

        onPressed: onTap,

        icon: Icon(

          icon,

          size: 17,

        ),

        label: Text(

          label,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

        ),

        style: OutlinedButton.styleFrom(

          foregroundColor: color,

          side: BorderSide(

            color: color.withOpacity(0.35),

          ),

          padding: const EdgeInsets.symmetric(

            horizontal: 6,

          ),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(9),

          ),

        ),

      ),

    );

  }

}