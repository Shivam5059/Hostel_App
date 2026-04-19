import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import '../../user_data.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudentDetailsView extends StatefulWidget {
  final int studentId;
  const StudentDetailsView({super.key, required this.studentId});

  @override
  State<StudentDetailsView> createState() => _StudentDetailsViewState();
}

class _StudentDetailsViewState extends State<StudentDetailsView> {
  late Future<Map<String, dynamic>?> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _detailsFuture = ApiManager.fetchStudentDetails(widget.studentId);
    });
  }

  Future<void> _unassignStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release Student'),
        content: const Text('Are you sure you want to remove yourself as the counselor for this student? They will return to the unassigned list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.white),
            child: const Text('Release'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ApiManager.unassignStudentFromCounselor(widget.studentId);
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student released successfully'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to release student')));
        }
      }
    }
  }

  Future<void> _removeStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Remove Student', style: TextStyle(color: Colors.red)),
        content: const Text('This action is IRREVERSIBLE. All attendance history, complaints, and account data for this student will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ApiManager.deleteStudent(widget.studentId);
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student removed successfully'), backgroundColor: Colors.red));
          Navigator.pop(context); // Go back to student list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove student')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Student Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Error fetching details", style: TextStyle(color: AppTheme.accentColor)));
          }

          final student = snapshot.data!;
          final att = student['attendance_summary'];
          final isMyStudent = UserSession.role == 'COUNSELOR' && student['counselor_id'] == UserSession.userId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Header
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    (student['name'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ).animate().fadeIn().scale(),
                const SizedBox(height: 16),
                Text(
                  student['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                ).animate().fadeIn(delay: 100.ms),
                Text(
                  student['roll_no'] != null ? '#${student['roll_no']}' : 'No Roll No',
                  style: const TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 32),

                // Info Cards
                _buildCard([
                  _buildRow(Icons.email_outlined, 'Email', student['email'] ?? 'N/A'),
                  const Divider(height: 32),
                  _buildRow(Icons.phone_outlined, 'Phone', student['phone'] ?? 'N/A'),
                ], 300),

                const SizedBox(height: 24),

                _buildCard([
                  _buildRow(Icons.apartment_outlined, 'Hostel', student['hostel_name'] ?? 'Not Assigned'),
                  const Divider(height: 32),
                  _buildRow(Icons.meeting_room_outlined, 'Room', student['room_number'] ?? 'Not Assigned'),
                ], 400),

                const SizedBox(height: 24),

                // Attendance Summary Block
                if (att != null) 
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text('Attendance Summary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text('${att['attendance_percentage']}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            )
                          ]
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Total', '${att['total_classes']}'),
                            _buildStatItem('Present', '${att['present_count']}'),
                            _buildStatItem('Absent', '${att['absent_count']}'),
                          ],
                        )
                      ],
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

                if (isMyStudent) ...[
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _unassignStudent,
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Release Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentColor,
                        side: const BorderSide(color: AppTheme.accentColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 12),
                  const Text(
                    'This student will be moved back to the unassigned list.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ).animate().fadeIn(delay: 700.ms),
                ],

                if (UserSession.role == 'RECTOR' || UserSession.role == 'ADMIN') ...[
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _removeStudent,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Remove Student Permanently', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(List<Widget> children, int delay) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1);
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.secondaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: AppTheme.secondaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 15, fontWeight: FontWeight.w600)),
          ]
        )
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
      ],
    );
  }
}
