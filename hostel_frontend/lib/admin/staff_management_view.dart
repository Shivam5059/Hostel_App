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

  void _showStaffForm({Map<String, dynamic>? staff}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StaffFormDialog(staff: staff, onSuccess: () async => _refresh()),
    );
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
                if (!context.mounted) return;
                CsvExportHelper.showExportDialog(context, 'Staff', csv);
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

class _StaffFormDialog extends StatefulWidget {
  final Map<String, dynamic>? staff;
  final Future<void> Function() onSuccess;

  const _StaffFormDialog({this.staff, required this.onSuccess});

  @override
  State<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<_StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passCtrl;
  late String _role;
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.staff?['name']);
    _emailCtrl = TextEditingController(text: widget.staff?['email']);
    _phoneCtrl = TextEditingController(text: widget.staff?['phone']);
    _passCtrl = TextEditingController();
    _role = widget.staff?['role'] ?? 'WARDEN';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    bool ok;
    String? error;
    if (widget.staff == null) {
      final res = await ApiManager.registerStaffAdmin({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'password': _passCtrl.text,
        'role': _role,
      });
      ok = res.$1;
      error = res.$2;
    } else {
      final res = await ApiManager.updateStaffAdmin(widget.staff!['user_id'], {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': _role,
      });
      ok = res.$1;
      error = res.$2;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      if (!context.mounted) return;
      Navigator.pop(context);
      await widget.onSuccess();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.staff == null ? 'Staff registered successfully!' : 'Staff updated successfully!'),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Operation failed'),
        backgroundColor: AppTheme.accentColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(widget.staff == null ? Icons.person_add_outlined : Icons.edit_outlined, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(widget.staff == null ? 'Add New Staff' : 'Edit Staff', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                enabled: !_loading,
                decoration: InputDecoration(labelText: 'Name', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              if (widget.staff == null) ...[
                TextFormField(
                  controller: _emailCtrl,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  enabled: !_loading,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _phoneCtrl,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Phone (Optional)', prefixIcon: const Icon(Icons.phone_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(labelText: 'Role', prefixIcon: const Icon(Icons.badge_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: ['RECTOR', 'WARDEN', 'COUNSELOR'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: _loading ? null : (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.staff == null ? 'Create' : 'Update', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
