import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MenuEditView extends StatefulWidget {
  const MenuEditView({super.key});

  @override
  State<MenuEditView> createState() => _MenuEditViewState();
}

class _MenuEditViewState extends State<MenuEditView> {
  static const _days  = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  static const _meals = ['Breakfast','Lunch','Dinner'];

  String _selectedDay = _days[DateTime.now().weekday - 1]; // Default to today
  Map<String, List<Map<String, dynamic>>> _menu = { 'Breakfast': [], 'Lunch': [], 'Dinner': [] };
  List<dynamic> _catalog = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiManager.fetchMenuForDay(_selectedDay),
      ApiManager.fetchFoodItemsCatalog(),
    ]);
    final menuData = results[0] as Map<String, dynamic>?;
    setState(() {
      _catalog = results[1] as List<dynamic>;
      _menu = {
        'Breakfast': _castItems(menuData?['menu']?['Breakfast']),
        'Lunch':     _castItems(menuData?['menu']?['Lunch']),
        'Dinner':    _castItems(menuData?['menu']?['Dinner']),
      };
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _castItems(dynamic raw) =>
      (raw as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _onDayChanged(String day) async {
    setState(() { _selectedDay = day; _loading = true; });
    final data = await ApiManager.fetchMenuForDay(day);
    setState(() {
      _menu = {
        'Breakfast': _castItems(data?['menu']?['Breakfast']),
        'Lunch':     _castItems(data?['menu']?['Lunch']),
        'Dinner':    _castItems(data?['menu']?['Dinner']),
      };
      _loading = false;
    });
  }

  void _openEditSheet(String meal) async {
    final currentIds = _menu[meal]!.map((i) => i['item_id'] as int).toSet();
    final selected = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditMealSheet(
        day: _selectedDay,
        meal: meal,
        catalog: _catalog,
        selectedIds: currentIds,
      ),
    );

    if (selected != null && mounted) {
      final success = await ApiManager.updateMealSlot(_selectedDay, meal, selected.toList());
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedDay $meal updated!'), backgroundColor: Colors.green),
        );
        _onDayChanged(_selectedDay); // Refresh
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day selector chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = _days[i];
              final isToday = day == _days[DateTime.now().weekday - 1];
              final isSelected = day == _selectedDay;
              return ChoiceChip(
                label: Text(day.substring(0, 3)), // Mon, Tue...
                selected: isSelected,
                onSelected: (_) => _onDayChanged(day),
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
                avatar: isToday && !isSelected
                  ? const Icon(Icons.circle, size: 8, color: AppTheme.primaryColor)
                  : null,
              );
            },
          ),
        ).animate().fadeIn(),

        const SizedBox(height: 20),

        // Meal cards
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              itemCount: _meals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) {
                final meal = _meals[i];
                final items = _menu[meal]!;
                final color = [Colors.orange, AppTheme.primaryColor, Colors.indigo][i];
                final icon  = [Icons.wb_sunny_outlined, Icons.lunch_dining_outlined, Icons.nights_stay_outlined][i];

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: color, size: 20),
                            const SizedBox(width: 8),
                            Text(meal, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _openEditSheet(meal),
                              icon: Icon(Icons.edit_outlined, size: 16, color: color),
                              label: Text('Edit', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: color.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Items
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: items.isEmpty
                          ? Text('No items set', style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic))
                          : Wrap(
                              spacing: 8, runSpacing: 8,
                              children: items.map((item) {
                                final isVeg = item['is_veg'] == true;
                                return Chip(
                                  avatar: Icon(Icons.circle, size: 10, color: isVeg ? Colors.green : Colors.red),
                                  label: Text(item['item_name'] ?? '', style: const TextStyle(fontSize: 13)),
                                  backgroundColor: Colors.grey.shade50,
                                  side: BorderSide(color: Colors.grey.shade200),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (80 * i).ms).slideY(begin: 0.05);
              },
            ),
          ),
      ],
    );
  }
}

// --- Bottom sheet for selecting food items for a meal slot ---
class _EditMealSheet extends StatefulWidget {
  final String day, meal;
  final List<dynamic> catalog;
  final Set<int> selectedIds;

  const _EditMealSheet({
    required this.day,
    required this.meal,
    required this.catalog,
    required this.selectedIds,
  });

  @override
  State<_EditMealSheet> createState() => _EditMealSheetState();
}

class _EditMealSheetState extends State<_EditMealSheet> {
  late Set<int> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.catalog.where((item) =>
      (item['item_name'] as String).toLowerCase().contains(_search.toLowerCase())
    ).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit ${widget.meal}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                      Text(widget.day, style: const TextStyle(color: AppTheme.textSecondaryColor)),
                    ],
                  ),
                ),
                // Selected count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('${_selected.length} selected', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Item list
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item   = filtered[i];
                final id     = item['item_id'] as int;
                final name   = item['item_name'] as String;
                final isVeg  = item['is_veg'] == 1;
                final checked = _selected.contains(id);

                return CheckboxListTile(
                  value: checked,
                  onChanged: (_) => setState(() => checked ? _selected.remove(id) : _selected.add(id)),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  secondary: Icon(Icons.circle, size: 12, color: isVeg ? Colors.green : Colors.red),
                  activeColor: AppTheme.primaryColor,
                  controlAffinity: ListTileControlAffinity.trailing,
                  dense: true,
                );
              },
            ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
