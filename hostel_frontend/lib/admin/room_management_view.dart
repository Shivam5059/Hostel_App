import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RoomManagementView extends StatefulWidget {
  final int hostelId;
  final String hostelName;
  const RoomManagementView({super.key, required this.hostelId, required this.hostelName});

  @override
  State<RoomManagementView> createState() => _RoomManagementViewState();
}

class _RoomManagementViewState extends State<RoomManagementView> {
  late Future<List<dynamic>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _roomsFuture = ApiManager.fetchRoomsAdmin(widget.hostelId);
    });
  }

  Future<void> _showRoomForm({Map<String, dynamic>? room}) async {
    final numCtrl = TextEditingController(text: room?['room_number']);
    final capCtrl = TextEditingController(text: room?['capacity']?.toString() ?? '4');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(room == null ? 'Add Room' : 'Edit Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Room Number')),
            const SizedBox(height: 12),
            TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(room == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      bool ok;
      String? error;
      final data = {
        'hostel_id': widget.hostelId,
        'room_number': numCtrl.text,
        'capacity': int.tryParse(capCtrl.text) ?? 4,
      };

      if (room == null) {
        final res = await ApiManager.createRoomAdmin(data);
        ok = res.$1;
        error = res.$2;
      } else {
        final res = await ApiManager.updateRoomAdmin(room['room_id'], data);
        ok = res.$1;
        error = res.$2;
      }

      if (ok) {
        _refresh();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Operation failed'), backgroundColor: AppTheme.accentColor));
      }
    }
  }

  Future<void> _deleteRoom(int id, String number) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Delete Room $number? This will fail if students are currently assigned to it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiManager.deleteRoomAdmin(id);
      if (res.$1) {
        _refresh();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.$2 ?? 'Delete failed'), backgroundColor: AppTheme.accentColor));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.hostelName} - Rooms')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<dynamic>>(
          future: _roomsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Error fetching rooms"));
            }

            final rooms = snapshot.data!;
            if (rooms.isEmpty) {
              return const Center(child: Text("No rooms found in this hostel"));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final r = rooms[index];
                final bool isFull = r['occupied'] >= r['capacity'];
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: isFull ? AppTheme.accentColor.withValues(alpha: 0.2) : Colors.transparent),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.meeting_room_outlined, color: AppTheme.primaryColor, size: 20),
                          ),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert, size: 18),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.accentColor))),
                            ],
                            onSelected: (val) {
                              if (val == 'edit') _showRoomForm(room: r);
                              if (val == 'delete') _deleteRoom(r['room_id'], r['room_number']);
                            },
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Room ${r['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(
                            '${r['occupied']} / ${r['capacity']} Occupied',
                            style: TextStyle(
                              color: isFull ? AppTheme.accentColor : AppTheme.textSecondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: r['occupied'] / r['capacity'],
                        backgroundColor: Colors.grey.shade100,
                        color: isFull ? AppTheme.accentColor : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (50 * index).ms).scale(begin: const Offset(0.9, 0.9));
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRoomForm(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
