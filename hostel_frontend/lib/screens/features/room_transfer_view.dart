import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import '../../user_data.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RoomTransferView extends StatefulWidget {
  const RoomTransferView({super.key});

  @override
  State<RoomTransferView> createState() => _RoomTransferViewState();
}

class _RoomTransferViewState extends State<RoomTransferView> {
  late Future<List<dynamic>> _requestsFuture;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      if (UserSession.role == 'STUDENT') {
        _requestsFuture = ApiManager.fetchStudentRoomTransfers();
      } else {
        _requestsFuture = ApiManager.fetchRoomTransfers();
      }
    });
    return;
  }

  Future<void> _handleStatusAction(int requestId, String status) async {
    setState(() => _processingIds.add(requestId));
    
    final success = await ApiManager.updateRoomTransferStatus(requestId, status);
    
    if (mounted) {
      setState(() => _processingIds.remove(requestId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Request marked as $status' : 'Action failed'),
        backgroundColor: success ? (status == 'APPROVED' ? Colors.green : Colors.red) : AppTheme.accentColor,
      ));
      if (success) _fetchRequests();
    }
  }

  void _showCreateRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateTransferSheet()
    ).then((_) {
      if (mounted) _fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = UserSession.role == 'STUDENT';
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isStudent ? FloatingActionButton.extended(
        onPressed: _showCreateRequestSheet,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Request', style: TextStyle(color: Colors.white)),
      ).animate().fadeIn().slideY(begin: 1) : null,
      body: RefreshIndicator(
        onRefresh: _fetchRequests,
        child: FutureBuilder<List<dynamic>>(
          future: _requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.accentColor),
                    const SizedBox(height: 16),
                    const Text('Failed to load transfers', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: _fetchRequests, child: const Text('Retry'))
                  ],
                ),
              );
            }

            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                   height: MediaQuery.of(context).size.height * 0.7,
                   child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No room transfer requests found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24.0),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                final isProcessing = _processingIds.contains(req['request_id']);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                         BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isStudent 
                                    ? 'To: ${req['requested_hostel']} - Rm ${req['requested_room']}' 
                                    : req['student_name'] ?? 'Unknown Student', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                                ),
                              ),
                              _buildStatusChip(req['status']),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!isStudent) ...[
                            Text('Current: ${req['current_hostel']} - Rm ${req['current_room']}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Requested: ${req['requested_hostel']} - Rm ${req['requested_room']}', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                          ],
                          Text('Reason: ${req['reason']}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                          
                          if (!isStudent && req['status'] == 'PENDING') ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: isProcessing ? null : () => _handleStatusAction(req['request_id'], 'REJECTED'),
                                  child: const Text('Reject', style: TextStyle(color: AppTheme.accentColor)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isProcessing ? null : () => _handleStatusAction(req['request_id'], 'APPROVED'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                                  child: isProcessing 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Approve', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            )
                          ]
                        ],
                      ),
                    ),
                  )
                ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.05);
              },
            );
          },
        ),
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

class _CreateTransferSheet extends StatefulWidget {
  const _CreateTransferSheet();
  @override
  State<_CreateTransferSheet> createState() => _CreateTransferSheetState();
}

class _CreateTransferSheetState extends State<_CreateTransferSheet> {
  final _reasonCtrl = TextEditingController();
  List<dynamic> _rooms = [];
  int? _selectedRoomId;
  bool _isLoadingRooms = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    try {
      final rooms = await ApiManager.fetchAvailableRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedRoomId == null || _reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a room and provide a reason')));
      return;
    }
    
    setState(() => _isSubmitting = true);
    final success = await ApiManager.submitRoomTransferRequest(_selectedRoomId!, _reasonCtrl.text);
    
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transfer request submitted!'),
          backgroundColor: Colors.green,
        ));
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to submit request.'),
          backgroundColor: AppTheme.accentColor,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          const Text('Request Room Transfer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
          const SizedBox(height: 24),
          if (_isLoadingRooms)
            const Center(child: CircularProgressIndicator())
          else if (_rooms.isEmpty)
             Text('No rooms available currently.', style: TextStyle(color: Colors.grey.shade600))
          else 
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Select Available Room',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              value: _selectedRoomId,
              items: _rooms.map((r) => DropdownMenuItem<int>(
                value: r['room_id'],
                child: Text('${r['hostel_name']} - Rm ${r['room_number']} (${r['capacity'] - r['occupied']} beds left)'),
              )).toList(),
              onChanged: _isSubmitting ? null : (val) => setState(() => _selectedRoomId = val),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Reason for Transfer',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Submit Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _handle() => Center(
      child: Container(
        width: 40, height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
      ),
    );
}
