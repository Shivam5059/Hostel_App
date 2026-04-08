import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../user_data.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ComplaintsView extends StatefulWidget {
  const ComplaintsView({super.key});

  @override
  State<ComplaintsView> createState() => _ComplaintsViewState();
}

class _ComplaintsViewState extends State<ComplaintsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _pendingFuture;
  late Future<List<dynamic>> _historyFuture;

  final bool _isStudent = UserSession.role == 'STUDENT';
  final bool _isRector  = UserSession.role == 'RECTOR';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      if (_isStudent) {
        _pendingFuture = ApiManager.fetchStudentComplaints();
        _historyFuture = Future.value([]); // student sees all in one list
      } else {
        _pendingFuture = ApiManager.fetchAllComplaints(status: 'PENDING');
        _historyFuture = ApiManager.fetchAllComplaints(); 
      }
    });
    return;
  }

  void _showSubmitDialog() {
    final ctrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental close while submitting
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Submit Complaint', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            maxLines: 4,
            enabled: !isSubmitting,
            decoration: InputDecoration(
              hintText: 'Describe your issue in detail...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (ctrl.text.trim().isEmpty) return;
                
                setDialogState(() => isSubmitting = true);
                final ok = await ApiManager.submitComplaint(ctrl.text.trim());
                
                if (!mounted) return;
                
                if (ok) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Complaint submitted successfully!'),
                    backgroundColor: Colors.green,
                  ));
                  _fetchData();
                } else {
                  setDialogState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to submit. Please try again.'),
                    backgroundColor: AppTheme.accentColor,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(100, 40)
              ),
              child: isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openComplaintDetail(Map<String, dynamic> c, {bool isHistory = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComplaintDetailSheet(
        complaint: c,
        isHistory: isHistory,
        isRector: _isRector,
        onAction: (status) async {
          // The detail sheet handles its own loading state now
          await _fetchData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _isStudent ? null : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [Tab(text: 'Pending'), Tab(text: 'History')],
        ),
      ),
      floatingActionButton: _isStudent
          ? FloatingActionButton.extended(
              onPressed: _showSubmitDialog,
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Complaint', style: TextStyle(color: Colors.white)),
            ).animate().fadeIn().slideY(begin: 1)
          : null,
      body: _isStudent
          ? _buildList(_pendingFuture, isHistory: false)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pendingFuture, isHistory: false),
                // History tab: fetch all, show only non-pending
                FutureBuilder<List<dynamic>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _buildErrorState();
                    }
                    final filtered = (snapshot.data ?? [])
                        .where((c) => c['status'] != 'PENDING')
                        .toList();
                    return _buildListFromData(filtered, isHistory: true, onRefresh: _fetchData);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildList(Future<List<dynamic>> future, {required bool isHistory}) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorState();
        }
        return _buildListFromData(snapshot.data ?? [], isHistory: isHistory, onRefresh: _fetchData);
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
          const Text('Failed to load complaints', style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(onPressed: _fetchData, child: const Text('Retry'))
        ],
      ),
    );
  }

  Widget _buildListFromData(List<dynamic> complaints, {required bool isHistory, required Future<void> Function() onRefresh}) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: complaints.isEmpty
          ? SingleChildScrollView( // Need scrollable for RefreshIndicator to work on empty
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        isHistory ? 'No complaints resolved yet.' : 'No pending complaints!',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ).animate().fadeIn(),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: complaints.length,
              itemBuilder: (context, index) {
                final c = complaints[index];
                return GestureDetector(
                  onTap: () => _openComplaintDetail(c, isHistory: isHistory),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _isStudent ? 'My Complaint' : (c['student_name'] ?? 'Unknown'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            _buildStatusChip(c['status']),
                          ],
                        ),
                        if (!_isStudent) ...[
                          const SizedBox(height: 4),
                          Text('Roll: ${c['roll_no'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          c['description'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              c['register_date']?.toString().split('T').first ?? '',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                            const Spacer(),
                            Text('Tap for details →', style: TextStyle(color: AppTheme.primaryColor.withValues(alpha: 0.7), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.05);
              },
            ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color bg = Colors.grey.shade200, fg = Colors.grey.shade700;
    if (status == 'RESOLVED') { bg = Colors.green.shade100; fg = Colors.green.shade800; }
    if (status == 'REJECTED') { bg = Colors.red.shade100;   fg = Colors.red.shade800; }
    if (status == 'PENDING')  { bg = Colors.orange.shade100; fg = Colors.orange.shade800; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status ?? 'UNKNOWN', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

// --- Full complaint detail bottom sheet ---
class _ComplaintDetailSheet extends StatefulWidget {
  final Map<String, dynamic> complaint;
  final bool isHistory;
  final bool isRector;
  final Future<void> Function(String status) onAction;

  const _ComplaintDetailSheet({
    required this.complaint,
    required this.isHistory,
    required this.isRector,
    required this.onAction,
  });

  @override
  State<_ComplaintDetailSheet> createState() => _ComplaintDetailSheetState();
}

class _ComplaintDetailSheetState extends State<_ComplaintDetailSheet> {
  bool _isProcessing = false;

  Future<void> _handleAction(String status) async {
    setState(() => _isProcessing = true);
    final ok = await ApiManager.updateComplaintStatus(widget.complaint['complaint_id'], status);
    
    if (!mounted) return;
    
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Complaint ${status.toLowerCase()} successfully!'),
        backgroundColor: status == 'RESOLVED' ? Colors.green : Colors.red,
      ));
      await widget.onAction(status);
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to update complaint status.'),
        backgroundColor: AppTheme.accentColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final isPending = c['status'] == 'PENDING';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Row(
            children: [
              const Text('Complaint Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              _statusChip(c['status']),
            ],
          ),
          const SizedBox(height: 20),

          if (widget.isRector) ...[
            _infoRow(Icons.person_outlined, 'Student', c['student_name'] ?? 'N/A'),
            const SizedBox(height: 12),
            _infoRow(Icons.numbers, 'Roll No', c['roll_no'] ?? 'N/A'),
            const SizedBox(height: 12),
          ],

          _infoRow(Icons.calendar_today_outlined, 'Registered', c['register_date']?.toString().split('T').first ?? 'N/A'),
          const SizedBox(height: 12),

          if (widget.isHistory && c['rector_name'] != null) ...[
            _infoRow(Icons.manage_accounts_outlined, 'Handled by', c['rector_name']),
            const SizedBox(height: 12),
            _infoRow(Icons.event_available_outlined, 'Resolved on', c['end_date']?.toString().split('T').first ?? 'N/A'),
            const SizedBox(height: 12),
          ],

          const Divider(height: 24),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor, fontSize: 13)),
          const SizedBox(height: 8),
          Text(c['description'] ?? '', style: const TextStyle(fontSize: 16, color: AppTheme.textPrimaryColor)),
          const SizedBox(height: 24),

          if (widget.isRector && isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _handleAction('REJECTED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentColor,
                      side: const BorderSide(color: AppTheme.accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor))
                      : const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handleAction('RESOLVED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Mark Resolved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryColor),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
      ],
    );
  }

  Widget _statusChip(String? status) {
    Color bg = Colors.grey.shade200, fg = Colors.grey.shade700;
    if (status == 'RESOLVED') { bg = Colors.green.shade100; fg = Colors.green.shade800; }
    if (status == 'REJECTED') { bg = Colors.red.shade100;   fg = Colors.red.shade800; }
    if (status == 'PENDING')  { bg = Colors.orange.shade100; fg = Colors.orange.shade800; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status ?? '', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
