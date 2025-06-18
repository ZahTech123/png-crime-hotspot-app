import 'package:flutter/material.dart';

class CustomBottomNavbar extends StatelessWidget {
  final int activeIndex;
  final Function(int) onTabChanged;

  const CustomBottomNavbar({
    super.key,
    required this.activeIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    // This widget now uses Flutter's built-in BottomAppBar for a cleaner,
    // more standard notched look.

    return BottomAppBar(
      shape: const CircularNotchedRectangle(), // This creates the "notch"
      notchMargin: 8.0, // Space between the FAB and the bar
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildTabItem(
            context: context,
            icon: Icons.list_alt,
            label: 'Complaints',
            index: 0,
          ),
          _buildTabItem(
            context: context,
            icon: Icons.map_outlined,
            label: 'Map',
            index: 1,
          ),
          // This SizedBox creates the space for the FloatingActionButton
          const SizedBox(width: 40), 
          _buildTabItem(
            context: context,
            icon: Icons.bar_chart,
            label: 'Reports',
            index: 2,
          ),
          _buildTabItem(
            context: context,
            icon: Icons.person_outline,
            label: 'Profile',
            index: 3,
          ),
        ],
      ),
    );
  }

  // Helper widget to build each tab item, reducing code duplication.
  Widget _buildTabItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    // Check if this tab is the currently active one.
    final bool isActive = index == activeIndex;
    final Color color = isActive ? Theme.of(context).primaryColor : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () => onTabChanged(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 