import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/screens/admin_screens/order_page/controllers/add_order_controller.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/color_temple_requirements.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/customer_details_form.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/order_details_form.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/product_table.dart';
import 'package:shotgun/screens/admin_screens/order_page/widgets/summary_section.dart';

class AddOrdersStepper extends StatefulWidget {
  const AddOrdersStepper({super.key});

  @override
  State<AddOrdersStepper> createState() => _AddOrdersStepperState();
}

class _AddOrdersStepperState extends State<AddOrdersStepper> {
  int _currentStep = 0;

  /// 🔹 Move to next step with validation
  void _nextStep(AddOrderController controller) {
    final currentForm =
        controller
            .formKeys[_currentStep < controller.formKeys.length
                ? _currentStep
                : controller.formKeys.length - 1]
            .currentState;

    if (currentForm != null && !currentForm.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all required fields before continuing',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ✅ Move between steps safely
    final totalSteps = controller.showColorCustomization ? 5 : 4;

    if (_currentStep < totalSteps - 1) {
      setState(() => _currentStep += 1);
    } else {
      // 🔹 Validate all forms before submission
      for (var formKey in controller.formKeys) {
        final form = formKey.currentState;
        if (form != null && !form.validate()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please fill in all required fields before submitting',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      // ✅ All forms valid → Submit order
      if (controller.isEditMode) {
        controller.saveOrder(context).then((_) {
          Navigator.pushReplacementNamed(context, '/admin/orders');
        });
      } else {
        controller.submitOrder(context).then((_) {
          Navigator.pushReplacementNamed(context, '/admin/orders');
        });
      }
    }
  }

  /// 🔹 Go back to previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AddOrderController>(context);

    /// 🔹 Dynamically build steps list based on order type
    final steps = [
      Step(
        title: const Text('Customer Details'),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        // content: CustomerDetailsForm(controller: controller),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomerDetailsForm(controller: controller),
            const SizedBox(height: 20),
            // 🔹 New Order Type Dropdown
            DropdownButtonFormField<String>(
              value: controller.orderType,
              decoration: const InputDecoration(
                labelText: 'Order Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'Stock', child: Text('Stock Order')),
                DropdownMenuItem(
                    value: 'Customized', child: Text('Customized Order')),
              ],
              onChanged: (value) {
                controller.setOrderType(value);
                // Reset step index if user switches order type mid-way
                if (!controller.showColorCustomization && _currentStep > 2) {
                  setState(() => _currentStep = 2);
                }
              },
            ),
          ],
        ),
      ),
      Step(
        title: const Text('Order Details'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: OrderDetailsForm(controller: controller),
      ),
      Step(
        title: const Text('Products'),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: ProductTable(controller: controller),
      ),
      // 🔹 Only show this step if the order type is Customized
      if (controller.showColorCustomization)
        Step(
          title: const Text('Color Customization'),
          isActive: _currentStep >= 3,
          state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          content: ColorTempleRequirements(controller: controller),
        ),
      Step(
        title: const Text('Summary'),
        isActive: _currentStep >=
            (controller.showColorCustomization ? 4 : 3),
        state: _currentStep ==
                (controller.showColorCustomization ? 4 : 3)
            ? StepState.editing
            : StepState.indexed,
        content: const SummarySection(),
      ),
    ];

    return Stepper(
      key: ValueKey(controller.showColorCustomization),
      type: StepperType.vertical,
      currentStep: _currentStep,
      onStepContinue: () => _nextStep(controller),
      onStepCancel: _previousStep,
      controlsBuilder: (context, details) {
        final isLastStep = controller.showColorCustomization
            ? _currentStep == 4
            : _currentStep == 3;

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                TextButton(onPressed: _previousStep, child: const Text('Back')),
              ElevatedButton(
                onPressed: () => _nextStep(controller),
                child: Text(isLastStep ? 'Finish' : 'Next'),
              ),
            ],
          ),
        );
      },
      steps: steps,
    );
  }
}
