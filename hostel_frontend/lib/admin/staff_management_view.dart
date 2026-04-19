import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'csv_helper.dart';

class StaffManagementView extends StatefulWidget {
  const StaffManagementView({super.key});

  @override
  State<StaffManagementView> createState() => _StaffManagementViewState();
}

class _StaffManagementViewState extends State<StaffManagementView> {
  late Future<List<dynamic>> _staffFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _staffFuture = ApiManager.fetchStaffAdmin();
    });
  }

  Future<void> _showStaffForm({Map<String, dynamic>? staff}) async {
    final nameCtrl = TextEditingController(text: staff?['name']);
    final emailCtrl = TextEditingController(text: staff?['email']);
    final phoneCtrl = TextEditingController(text: staff?['phone']);
    final passCtrl = TextEditingController();
    String role = staff?['role'] ?? 'WARDEN';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(staff == null ? 'Add New Staff' : 'Edit Staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                if (staff == null) ...[
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                  const SizedBox(height: 12),
                ],
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['RECTOR', 'WARDEN', 'COUNSELOR'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(staff == null ? 'Create' : 'Update'),
            ),
          ],
        );
      }),
    );

    if (result == true) {
      bool ok;
      String? error;
      if (staff == null) {
        final res = await ApiManager.registerStaffAdmin({
          'name': nameCtrl.text,
          'email': emailCtrl.text,
          'phone': phoneCtrl.text,
          'password': passCtrl.text,
          'role': role,
        });
        ok = res.$1;
        error = res.$2;
      } else {
        final res = await ApiManager.updateStaffAdmin(staff['user_id'], {
          'name': nameCtrl.text,
          'phone': phoneCtrl.text,
          'role': role,
        });
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

  Future<void> _deleteStaff(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiManager.deleteStaffAdmin(id);
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
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to CSV',
            onPressed: () async {
              final staff = await ApiManager.fetchStaffAdmin();
              if (staff.isNotEmpty) {
                final csv = CsvExportHelper.convertToCsv(
                  staff, 
                  ['Name', 'Email', 'Role', 'Phone', 'Hostel'], 
                  ['name', 'email', 'role', 'phone', 'hostel_name']
                );
                if (mounted) CsvExportHelper.showExportDialog(context, 'Staff', csv);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<dynamic>>(
          future: _staffFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Error fetching staff"));
            }

            final staff = snapshot.data!;
            if (staff.isEmpty) {
              return const Center(child: Text("No staff members found"));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: staff.length,
              itemBuilder: (context, index) {
                final s = staff[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Text((s['role'] ?? ' ')[0], style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(s['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${s['role']}\n${s['email']}\n${s['hostel_name'] != null ? "Hostel: ${s['hostel_name']}" : "No Assignment"}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showStaffForm(staff: s)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.accentColor, size: 20), onPressed: () => _deleteStaff(s['user_id'], s['name'])),
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
        onPressed: () => _showStaffForm(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
