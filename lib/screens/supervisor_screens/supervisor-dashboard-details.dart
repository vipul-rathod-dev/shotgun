import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Compact order overview embedded in SupervisorDashboard.
///
/// This widget intentionally has no Scaffold, AppBar, Expanded, ListView,
/// or GridView. It therefore cannot overlap the dashboard card GridView.
class SupervisorDashboardDetails extends StatelessWidget {
  const SupervisorDashboardDetails({super.key});

  Future<String?> _getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cachedCompanyId');
  }

  String _groupOfStatus(String? status) {
    final value = (status ?? '').trim().toLowerCase();

    const pending = {
      'received',
      'pending',
      'yet to start',
      'new',
    };

    const inProgress = {
      'raw process',
      'color process',
      'quality check',
      'fitting process',
      'demo process',
      'packing process',
      'processing',
      'in progress',
      'started',
    };

    const completed = {
      'completed',
      'shipping',
      'shipped',
      'delivered',
      'closed',
    };

    const cancelled = {
      'cancelled',
      'canceled',
    };

    if (pending.contains(value)) return 'Pending';
    if (inProgress.contains(value)) return 'In Progress';
    if (completed.contains(value)) return 'Completed';
    if (cancelled.contains(value)) return 'Cancelled';

    // Keep unknown operational statuses visible.
    return 'In Progress';
  }

  Color _color(String group) {
    switch (group) {
      case 'Pending':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _icon(String group) {
    switch (group) {
      case 'Pending':
        return Icons.schedule_outlined;
      case 'In Progress':
        return Icons.autorenew_rounded;
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getCompanyId(),
      builder: (context, companySnapshot) {
        if (companySnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 92,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final companyId = companySnapshot.data;
        if (companyId == null || companyId.isEmpty) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('orders')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 92,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return _errorCard(context);
            }

            final docs = snapshot.data?.docs ?? [];

            int pending = 0;
            int inProgress = 0;
            int completed = 0;
            int cancelled = 0;

            for (final doc in docs) {
              final status =
                  doc.data()['orderStatus']?.toString();

              switch (_groupOfStatus(status)) {
                case 'Pending':
                  pending++;
                  break;
                case 'In Progress':
                  inProgress++;
                  break;
                case 'Completed':
                  completed++;
                  break;
                case 'Cancelled':
                  cancelled++;
                  break;
              }
            }

            return _buildOverview(
              context,
              total: docs.length,
              pending: pending,
              inProgress: inProgress,
              completed: completed,
              cancelled: cancelled,
            );
          },
        );
      },
    );
  }

  Widget _buildOverview(
    BuildContext context, {
    required int total,
    required int pending,
    required int inProgress,
    required int completed,
    required int cancelled,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isSmall = width < 600;

    final cards = [
      _OrderSummaryCard(
        title: 'All Orders',
        count: total,
        icon: Icons.receipt_long_outlined,
        color: Colors.indigo,
      ),
      _OrderSummaryCard(
        title: 'Pending',
        count: pending,
        icon: _icon('Pending'),
        color: _color('Pending'),
      ),
      _OrderSummaryCard(
        title: 'In Progress',
        count: inProgress,
        icon: _icon('In Progress'),
        color: _color('In Progress'),
      ),
      _OrderSummaryCard(
        title: 'Completed',
        count: completed,
        icon: _icon('Completed'),
        color: _color('Completed'),
      ),
      _OrderSummaryCard(
        title: 'Cancelled',
        count: cancelled,
        icon: _icon('Cancelled'),
        color: _color('Cancelled'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Order Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF343741),
                ),
              ),
            ),
            Text(
              '$total total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fixed compact height. On mobile the cards scroll horizontally,
        // but this widget itself never grows into the dashboard grid.
        SizedBox(
          height: isSmall ? 76 : 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return cards[index];
            },
          ),
        ),
      ],
    );
  }

  Widget _errorCard(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unable to load order summary.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _OrderSummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 400 ? 142.0 : width < 600 ? 155.0 : 175.0;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$count',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF343741),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
