import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'csv_helper.dart';
import 'room_management_view.dart';

class HostelManagementView extends StatefulWidget {
  const HostelManagementView({super.key});

  @override
  State<HostelManagementView> createState() => _HostelManagementViewState();
}

class _HostelManagementViewState extends State<HostelManagementView> {
  late Future<List<dynamic>> _hostelsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _hostelsFuture = ApiManager.fetchHostelsAdmin();
    });
  }

  Future<void> _assignWarden(int hostelId, String hostelName) async {
    // Fetch all staff to find Wardens
    final staff = await ApiManager.fetchStaffAdmin();
    final wardens = staff.where((s) => s['role'] == 'WARDEN').toList();

    if (!mounted) return;

    final selectedWardenId = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Warden to $hostelName'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: wardens.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) return ListTile(title: const Text('None (Unassign)'), onTap: () => Navigator.pop(ctx, null));
              final w = wardens[i - 1];
              return ListTile(
                title: Text(w['name']),
                subtitle: Text(w['email']),
                onTap: () => Navigator.pop(ctx, w['user_id']),
              );
            },
          ),
        ),
      ),
    );

    if (selectedWardenId != -2) { // -2 is just a sentinel for "dismissed without action"
       // But wait, the dialog returns null for unassign. 
       // If dismissed, it's null too. I should use a more robust way.
    }
    
    // Actually, let's just use the selectedWardenId if the dialog wasn't dismissed.
    // To distinguish dismiss from "None", I'll use -1 for None.
  }

  Future<void> _showHostelForm({Map<String, dynamic>? hostel}) async {
    final nameCtrl = TextEditingController(text: hostel?['hostel_name']);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hostel == null ? 'Add Hostel' : 'Edit Hostel'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Hostel Name', hintText: 'e.g. Boys Hostel B'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hostel == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty) {
      bool ok;
      String? error;
      if (hostel == null) {
        final res = await ApiManager.createHostelAdmin(nameCtrl.text);
        ok = res.$1;
        error = res.$2;
      } else {
        final res = await ApiManager.updateHostelAdmin(hostel['hostel_id'], nameCtrl.text);
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

  // Simplified version of the dialog result handling
  Future<void> _handleWardenAssignment(int hostelId, int? wardenId) async {
    final ok = await ApiManager.assignWardenAdmin(hostelId, wardenId);
    if (ok) {
      _refresh();
    }
  }

  Future<void> _deleteHostel(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Hostel'),
        content: Text('Are you sure you want to delete $name? This will fail if there are rooms or students assigned to it.'),
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
      final res = await ApiManager.deleteHostelAdmin(id);
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
      appBar: AppBar(
        title: const Text('Hostel Infrastructure'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to CSV',
            onPressed: () async {
              final hostels = await ApiManager.fetchHostelsAdmin();
              if (hostels.isNotEmpty) {
                final csv = CsvExportHelper.convertToCsv(
                  hostels, 
                  ['Hostel Name', 'Warden'], 
                  ['hostel_name', 'warden_name']
                );
                if (mounted) CsvExportHelper.showExportDialog(context, 'Hostels', csv);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<dynamic>>(
          future: _hostelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Error fetching hostels"));
            }

            final hostels = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: hostels.length,
              itemBuilder: (context, index) {
                final h = hostels[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (ctx) => RoomManagementView(hostelId: h['hostel_id'], hostelName: h['hostel_name']),
                      ));
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: const Icon(Icons.domain_outlined, color: AppTheme.primaryColor, size: 32),
                    title: Text(h['hostel_name'] ?? 'Unknown Hostel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text('Warden: ${h['warden_name'] ?? "Not Assigned"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showHostelForm(hostel: h)),
                        IconButton(
                          icon: const Icon(Icons.person_add_alt_1_outlined, size: 20), 
                          onPressed: () => _showWardenPicker(h['hostel_id'], h['hostel_name']),
                          tooltip: 'Assign Warden',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.accentColor, size: 20),
                          onPressed: () => _deleteHostel(h['hostel_id'], h['hostel_name']),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.05);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHostelForm(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showWardenPicker(int hostelId, String hostelName) async {
    final staff = await ApiManager.fetchStaffAdmin();
    final wardens = staff.where((s) => s['role'] == 'WARDEN').toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign Warden to $hostelName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: wardens.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return ListTile(
                      leading: const Icon(Icons.person_off_outlined),
                      title: const Text('No Warden (Unassign)'),
                      onTap: () {
                        _handleWardenAssignment(hostelId, null);
                        Navigator.pop(ctx);
                      },
                    );
                  }
                  final w = wardens[i - 1];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(w['name']),
                    subtitle: Text(w['email']),
                    onTap: () {
                      _handleWardenAssignment(hostelId, w['user_id']);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
