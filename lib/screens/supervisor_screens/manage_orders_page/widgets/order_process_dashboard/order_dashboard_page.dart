import 'package:flutter/material.dart';

import 'process_steps/color_process_page.dart';
import 'process_steps/demo_process_page.dart';
import 'process_steps/fitting_process_page.dart';
import 'process_steps/packing_process_page.dart';
import 'process_steps/raw_process_page.dart';
import 'process_steps/shipping_process_page.dart';

class OrderDashboardPage extends StatefulWidget {
  final String companyId;
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDashboardPage({
    super.key,
    required this.companyId,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<OrderDashboardPage> createState() => _OrderDashboardPageState();
}

class _OrderDashboardPageState extends State<OrderDashboardPage> {
  int _currentStep = 0;
  late final List<String> steps;

  @override
  void initState() {
    super.initState();

    if (widget.orderData['orderType'] == 'Customized') {
      steps = [
        'Raw Process',
        'Color Process',
        'Fitting Process',
        'Demo Process',
        'Packing',
        'Shipping',
      ];
    } else {
      steps = ['Packing', 'Shipping'];
    }

    _currentStep = _getStepIndexFromStatus(widget.orderData['orderStatus']);
  }

  int _getStepIndexFromStatus(String? status) {
    if (status == null) return 0;

    final normalizedStatus = status.trim().toLowerCase();

    final mapping = {
      'received': 'Raw Process',
      'raw process': 'Color Process',
      'color process': 'Fitting Process',
      'fitting process': 'Demo Process',
      'demo process': 'Packing',
      'packing': 'Shipping',
      'shipping': 'Shipping',
    };

    final nextStepName = mapping[normalizedStatus];
    if (nextStepName == null) return 0;

    final index = steps.indexWhere(
      (s) => s.toLowerCase() == nextStepName.toLowerCase(),
    );

    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Dashboard')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildHorizontalStepper(),
          const Divider(height: 24),
          _buildStepContent()
          // Expanded(
          //   child: AnimatedSwitcher(
          //     duration: const Duration(milliseconds: 300),
          //     transitionBuilder: (child, anim) =>
          //         FadeTransition(opacity: anim, child: child),
          //     child: _buildStepContent(),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildHorizontalStepper() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _currentStep = index),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isCompleted
                          ? Colors.green
                          : isActive
                              ? Colors.blue
                              : Colors.grey[400],
                      child: Icon(
                        isCompleted ? Icons.check : Icons.circle,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.blue : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              if (index != steps.length - 1)
                Container(
                  width: 40,
                  height: 2,
                  color: index < _currentStep ? Colors.green : Colors.grey[300],
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    final stepName = steps[_currentStep];

    switch (stepName) {
      case 'Raw Process':
        return RawProcessPage(
          companyId: widget.companyId,
          orderId: widget.orderId,
          orderData: widget.orderData,
        );
      case 'Color Process':
        return ColorProcessPage(
          companyId: widget.companyId,
          orderId: widget.orderId,
          orderData: widget.orderData,
        );
      case 'Fitting Process':
        return FittingProcessPage(
          companyId: widget.companyId,
          orderId: widget.orderId,
          orderData: widget.orderData,
        );
      case 'Demo Process':
        return DemoProcessPage(
          companyId: widget.companyId,
          orderId: widget.orderId,
          orderData: widget.orderData,
        );
      case 'Packing':
        return PackingProcessPage(
          companyId: widget.companyId,
          orderId: widget.orderId,
          orderData: widget.orderData,
        );
      case 'Shipping':
        return ShippingProcessPage(
          companyId: widget.companyId,
          orderId: widget.orderId,
          orderData: widget.orderData,
        );
      default:
        return const Center(child: Text('Unknown step'));
    }
  }
}
