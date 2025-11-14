// controllers/order_details_controller.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_formatter.dart';
import 'product_totals_calculator.dart';
import 'order_status_mapper.dart';

class OrderDetailsController {
  final ValueNotifier<String?> companyId = ValueNotifier<String?>(null);
  int _previousStep = 0;

  OrderDetailsController();

  void dispose() {
    companyId.dispose();
  }

  Future<void> loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    companyId.value = prefs.getString('cachedCompanyId');
  }

  void resetPreviousStep() {
    _previousStep = 0;
  }

  Map<String, int> computeTotals(List<dynamic> products) {
    return ProductTotalsCalculator.compute(products);
  }

  String formatDate(dynamic ts) => DateFormatter.formatTimestamp(ts);

  int _statusToStepIndex(String? status) => OrderStatusMapper.statusToStepIndex(status);

  /// Resolve a step value (keeps behaviour of original file)
  int resolveCurrentStep({String? statusField, required Map<String, dynamic> data}) {
    int currentStep = _statusToStepIndex(statusField);

    // legacy simple mapping fallback to Created/Processing/Shipped/Delivered
    switch (statusField) {
      case 'Created':
        currentStep = 0;
        break;
      case 'Processing':
        currentStep = 1;
        break;
      case 'Shipped':
        currentStep = 2;
        break;
      case 'Delivered':
        currentStep = 3;
        break;
      default:
        currentStep = currentStep;
    }

    if (statusField == null || statusField.trim().isEmpty) {
      final bool hasOrderDate = data['orderDate'] != null;
      final bool hasShippingDate = data['shippingDate'] != null;
      final bool hasDeliveryDate = data['deliveryDate'] != null;
      if (hasDeliveryDate) {
        currentStep = 3;
      } else if (hasShippingDate) {currentStep = 2;}
      else if (hasOrderDate) {currentStep = 1;}
      else {currentStep = 0;}

      if (currentStep != _previousStep) {
        _previousStep = currentStep;
      }
    }

    return currentStep;
  }
}
