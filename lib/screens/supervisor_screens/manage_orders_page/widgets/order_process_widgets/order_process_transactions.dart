import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_order_process_transactions.dart';

class OrderProcessTransactionsPage extends StatefulWidget {
  final String orderId;
  final String processType;
  final String processTitle;
  final User currentUser;

  const OrderProcessTransactionsPage({
    super.key,
    required this.orderId,
    required this.processType,
    required this.processTitle,
    required this.currentUser,
  });

  @override
  State<OrderProcessTransactionsPage> createState() =>
      _OrderProcessTransactionsPageState();
}

class _OrderProcessTransactionsPageState
    extends State<OrderProcessTransactionsPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _companyId;

  bool get isRawMaterial => widget.processType == 'raw_material';

  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('cachedCompanyId');
    setState(() {
      _companyId = companyId;
      _tabController = TabController(
        length: isRawMaterial ? 1 : 2,
        vsync: this,
      );
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot> _orderProcessStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('processTransactions')
        .doc(widget.orderId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (_companyId == null || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.processTitle} - Order #${widget.orderId}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: isRawMaterial
              ? const [Tab(text: 'Outgoing')]
              : const [Tab(text: 'Incoming'), Tab(text: 'Outgoing')],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _orderProcessStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No transactions found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final processes = data['processes'] as Map<String, dynamic>? ?? {};
          final processData =
              processes[widget.processType] as Map<String, dynamic>? ?? {};

          final incomingList =
              List<Map<String, dynamic>>.from(processData['incoming'] ?? []);
          final outgoingList =
              List<Map<String, dynamic>>.from(processData['outgoing'] ?? []);

          return TabBarView(
            controller: _tabController,
            children: isRawMaterial
                ? [_buildTransactionList(outgoingList, 'outgoing')]
                : [
                    _buildTransactionList(incomingList, 'incoming'),
                    _buildTransactionList(outgoingList, 'outgoing'),
                  ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final txType = isRawMaterial
              ? 'outgoing'
              : _tabController!.index == 0
                  ? 'incoming'
                  : 'outgoing';

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddOrderProcessTransactionPage(
                orderId: widget.orderId,
                processType: widget.processType,
                processTitle: widget.processTitle,
                transactionType: txType,
                currentUser: widget.currentUser,
                companyId: _companyId!,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }

  Widget _buildTransactionList(
      List<Map<String, dynamic>> materials, String transactionType) {
    if (materials.isEmpty) {
      return Center(child: Text('No $transactionType transactions'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: materials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = materials[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(item['unit'] ?? 'pcs')),
            title: Text('${item['name']} — ${item['quantity']} ${item['unit']}'),
            subtitle: Text(transactionType.toUpperCase()),
          ),
        );
      },
    );
  }
}
