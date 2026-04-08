import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MenuView extends StatefulWidget {
  const MenuView({super.key});

  @override
  State<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<MenuView> {
  late Future<Map<String, dynamic>?> _menuFuture;

  @override
  void initState() {
    super.initState();
    _menuFuture = ApiManager.fetchTodaysMenu();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _menuFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No menu available', style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ).animate().fadeIn(),
          );
        }

        final day  = snapshot.data!['day'] as String;
        final menu = Map<String, dynamic>.from(snapshot.data!['menu']);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Text("Today's Menu", style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 16)),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 24),

              // Meal cards
              _buildMealCard('Breakfast', Icons.wb_sunny_outlined,    menu['Breakfast'], Colors.orange,      0),
              const SizedBox(height: 16),
              _buildMealCard('Lunch',     Icons.lunch_dining_outlined, menu['Lunch'],     AppTheme.primaryColor, 100),
              const SizedBox(height: 16),
              _buildMealCard('Dinner',    Icons.nights_stay_outlined,  menu['Dinner'],    Colors.indigo,     200),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMealCard(String meal, IconData icon, dynamic items, Color color, int delay) {
    final itemList = (items as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal type header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Text(meal, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('${itemList.length} items', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Food item chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: itemList.isEmpty
              ? Text('Menu not set yet', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic))
              : Wrap(
                  spacing: 8, runSpacing: 8,
                  children: itemList.map((item) => _buildItemChip(item)).toList(),
                ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.05);
  }

  Widget _buildItemChip(Map<String, dynamic> item) {
    final isVeg = item['is_veg'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: isVeg ? Colors.green : Colors.red),
          const SizedBox(width: 6),
          Text(item['item_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
