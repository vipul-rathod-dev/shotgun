import 'package:flutter/material.dart';

// Used in order_details_insights_page.dart

class OrderTimeline extends StatelessWidget {
  final String status;
  final String orderType;
  // final Map<String, DateTime?> statusDates;

  const OrderTimeline({
    super.key,
    required this.status,
    required this.orderType,
    // required this.statusDates,
  });

  @override
  Widget build(BuildContext context) {
    final stockStatuses = [
      "Received",
      "Packing",
      "Shipping"
    ];
    final customizedStatuses = [
      "Received",
      "Raw Process",
      "Color Process",
      "Quality Check",
      "Fitting Process",
      "Demo Process",
      "Packing",
      "Shipping",
    ];

    final statuses = orderType.toLowerCase() == "customized order"
        ? customizedStatuses
        : stockStatuses;

    final activeIndex = statuses.indexOf(status);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: statuses.length * 140, // adjust width per step
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Row(
          children: List.generate(statuses.length, (index) {
            final isCompleted = index <= activeIndex;
            final isActive = index == activeIndex;
            final step = statuses[index];
            // final date = statusDates[step];
            // final formattedDate =
            //     date != null ? DateFormat('MMM d, h:mm a').format(date) : 'N/A';

            return Tooltip(
              message: step,
              preferBelow: true,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(color: Colors.white),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isCompleted
                            ? const LinearGradient(
                                colors: [Colors.green, Colors.lightGreenAccent],
                              )
                            : const LinearGradient(
                                colors: [Colors.grey, Colors.grey],
                              ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Icon(
                        isCompleted ? Icons.check : Icons.circle,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 90,
                      child: Text(
                        step,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isActive ? Colors.green.shade700 : Colors.black54,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (index < statuses.length - 1)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        height: 3,
                        width: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCompleted
                                ? [Colors.green, Colors.lightGreenAccent]
                                : [Colors.grey.shade400, Colors.grey.shade300],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
