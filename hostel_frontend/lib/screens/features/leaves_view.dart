import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../user_data.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../admin/csv_helper.dart';

class LeavesView extends StatefulWidget {
  const LeavesView({super.key});

  @override
  State<LeavesView> createState() => _LeavesViewState();
}

class _LeavesViewState extends State<LeavesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _pendingFuture;
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _pendingFuture = ApiManager.fetchLeaves(history: false);
      _historyFuture = ApiManager.fetchLeaves(history: true);
    });
    return;
  }

  void _showSubmitDialog() {
    final reasonCtrl = TextEditingController();
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    DateTime? fromDateTime;
    DateTime? toDateTime;
    bool isSubmitting = false;

    // Helper to format date & time for display or backend
    String formatDateTime(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

    // Helper to pick both date and time
    Future<DateTime?> pickDateTime(DateTime initialDate, DateTime firstDate) async {
      final date = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date == null) return null;

      if (!mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (time == null) return null;

      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request Leave'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fromCtrl, 
                  readOnly: true,
                  enabled: !isSubmitting,
                  onTap: () async {
                    final now = DateTime.now();
                    // Initial = tomorrow if we want, but allow today
                    final initial = fromDateTime ?? now.add(const Duration(hours: 1));
                    final picked = await pickDateTime(initial, now);
                    
                    if (picked != null) {
                      if (picked.isBefore(now)) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a future time'), backgroundColor: AppTheme.accentColor)
                        );
                        return;
                      }
                      setDialogState(() {
                        fromDateTime = picked;
                        fromCtrl.text = formatDateTime(picked);
                        // Reset 'To' if it's now before 'From'
                        if (toDateTime != null && toDateTime!.isBefore(fromDateTime!)) {
                          toDateTime = null;
                          toCtrl.clear();
                        }
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'From Date & Time', 
                    hintText: 'Select start',
                    prefixIcon: Icon(Icons.access_time, size: 20),
                  )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: toCtrl, 
                  readOnly: true,
                  enabled: !isSubmitting && fromDateTime != null,
                  onTap: () async {
                    if (fromDateTime == null) return;
                    final initial = toDateTime ?? fromDateTime!.add(const Duration(hours: 2));
                    final picked = await pickDateTime(initial, fromDateTime!);
                    
                    if (picked != null) {
                      if (picked.isBefore(fromDateTime!)) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('To time must be after From time'), backgroundColor: AppTheme.accentColor)
                        );
                        return;
                      }
                      setDialogState(() {
                        toDateTime = picked;
                        toCtrl.text = formatDateTime(picked);
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'To Date & Time', 
                    hintText: fromDateTime == null ? 'Select "From" first' : 'Select end',
                    prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                  )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl, 
                  maxLines: 2, 
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Reason', 
                    hintText: 'Going home, function...',
                    prefixIcon: Icon(Icons.edit_note),
                  )
                ),
              ],
            )
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (reasonCtrl.text.isEmpty || fromDateTime == null || toDateTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                
                setDialogState(() => isSubmitting = true);
                final ok = await ApiManager.submitLeaveRequest(
                  formatDateTime(fromDateTime!), 
                  formatDateTime(toDateTime!), 
                  reasonCtrl.text
                );
                
                if (!mounted) return;
                
                if (ok) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Leave request submitted!'),
                    backgroundColor: Colors.green,
                  ));
                  _fetchData();
                } else {
                  setDialogState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to submit request.'),
                    backgroundColor: AppTheme.accentColor,
                  ));
                }
              },
              child: isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit'),
            )
          ],
        ),
      )
    );
  }

  // Track processing states for each leave ID to prevent multi-clicks
  final Set<int> _processingIds = {};

  Future<void> _handleAction(int id, bool approve) async {
    setState(() => _processingIds.add(id));
    
    final ok = await ApiManager.processLeaveAction(id, approve);
    
    if (mounted) {
      setState(() => _processingIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? (approve ? 'Approved!' : 'Rejected!') : 'Action failed.'),
        backgroundColor: ok ? (approve ? Colors.green : Colors.red) : AppTheme.accentColor,
      ));
      if (ok) _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isStudent = UserSession.role == 'STUDENT';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isStudent ? null : TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        indicatorColor: AppTheme.primaryColor,
        tabs: const [Tab(text: 'Pending Approvals'), Tab(text: 'History')],
      ),
      floatingActionButton: isStudent
          ? FloatingActionButton.extended(
              onPressed: _showSubmitDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Request Leave', style: TextStyle(color: Colors.white)),
              backgroundColor: AppTheme.primaryColor,
            ).animate().fadeIn().slideY(begin: 1)
          : (UserSession.role == 'WARDEN' || UserSession.role == 'COUNSELOR' || UserSession.role == 'ADMIN')
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final pending = await ApiManager.fetchLeaves(history: false);
                    final history = await ApiManager.fetchLeaves(history: true);
                    final allLeaves = [...pending, ...history];
                    if (allLeaves.isNotEmpty) {
                      final mappedLeaves = allLeaves.map((l) {
                        String getApprovalStatus(dynamic val) {
                          if (val == 1) return 'Approved';
                          if (val == -1) return 'Rejected';
                          return 'Pending';
                        }
                        
                        // We copy the map since we're adding new properties
                        return {
                          ...Map<String, dynamic>.from(l),
                          'parent_status': getApprovalStatus(l['parent_approved']),
                          'counselor_status': getApprovalStatus(l['counselor_approved']),
                          'warden_status': getApprovalStatus(l['warden_approved']),
                        };
                      }).toList();

                      final csv = CsvExportHelper.convertToCsv(
                        mappedLeaves,
                        ['Student Name', 'From', 'To', 'Reason', 'Parent Approval', 'Counselor Approval', 'Warden Approval', 'Final Status'],
                        ['student_name', 'from_date', 'to_date', 'reason', 'parent_status', 'counselor_status', 'warden_status', 'status'],
                      );
                      if (context.mounted) CsvExportHelper.showExportDialog(context, 'Leaves', csv);
                    } else {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leave data to export.')));
                    }
                  },
                  icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                  label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
                  backgroundColor: AppTheme.primaryColor,
                ).animate().fadeIn()
              : null,
      body: isStudent
          ? _buildList(_pendingFuture, true)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pendingFuture, false),
                _buildList(_historyFuture, false, isHistoryTab: true),
              ],
            ),
    );
  }

  Widget _buildList(Future<List<dynamic>> future, bool isStudent, {bool isHistoryTab = false}) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _buildErrorState();
        
        final leaves = snapshot.data ?? [];
        
        return RefreshIndicator(
          onRefresh: _fetchData,
          child: leaves.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Text('No leave records found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 18)).animate().fadeIn()
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                itemCount: leaves.length,
                itemBuilder: (context, index) {
                  final l = leaves[index];
                  final isProcessing = _processingIds.contains(l['leave_id']);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l['student_name'] ?? 'Your Request', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              _buildStatusChip(l['status']),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${l['from_date']}  to  ${l['to_date']}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Reason: ${l['reason']}'),

                          if (!isStudent && !isHistoryTab && UserSession.role != 'ADMIN') ...[
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                 TextButton(
                                   onPressed: isProcessing ? null : () => _handleAction(l['leave_id'], false),
                                   child: const Text('Reject', style: TextStyle(color: AppTheme.accentColor)),
                                 ),
                                 const SizedBox(width: 8),
                                 ElevatedButton(
                                   onPressed: isProcessing ? null : () => _handleAction(l['leave_id'], true),
                                   child: isProcessing 
                                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                     : const Text('Approve'),
                                 )
                              ],
                            )
                          ]
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.05);
                },
              ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.accentColor),
          const SizedBox(height: 16),
          const Text('Failed to load leaves', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(onPressed: _fetchData, child: const Text('Retry'))
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade700;
    if (status == 'APPROVED') { bg = Colors.green.shade100; fg = Colors.green.shade800; }
    if (status == 'REJECTED') { bg = Colors.red.shade100; fg = Colors.red.shade800; }
    if (status == 'PENDING') { bg = Colors.orange.shade100; fg = Colors.orange.shade800; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status ?? 'UNKNOWN', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
