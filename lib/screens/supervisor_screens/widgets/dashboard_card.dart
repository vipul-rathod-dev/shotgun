import 'package:flutter/material.dart';

class DashboardCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hovered
                  ? [const Color(0xFF42A5F5), const Color(0xFF1565C0)]
                  : [Colors.white, Colors.grey.shade100],
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? Colors.blueAccent.withOpacity(0.35)
                    : Colors.grey.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 46, color: _hovered ? Colors.white : const Color(0xFF1565C0)),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _hovered ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
